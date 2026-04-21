import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rive/rive.dart';

import '../../../core/security/rive_crypto_service.dart';
import '../../../core/env/env.dart';
import '../../../core/network/api_client.dart';
import '../../community_stories/models/rive_element_model.dart';
import '../models/mascot_model.dart';

class MascotCacheException implements Exception {
  MascotCacheException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MascotCacheService {
  MascotCacheService({
    Dio? dio,
    RiveCryptoService? cryptoService,
    FutureOr<void> Function(List<String> deletedPaths)? onFilesDeleted,
  }) : _dio = dio ?? _defaultDio(),
       _cryptoService = cryptoService ?? RiveCryptoService(),
       _onFilesDeleted = onFilesDeleted;
  final Dio _dio;
  final RiveCryptoService _cryptoService;
  final FutureOr<void> Function(List<String> deletedPaths)? _onFilesDeleted;

  static const int _defaultConcurrentDownloads = 3;
  static const int _maxCacheFiles = 24;
  static const Duration _maxAge = Duration(days: 60);

  static Dio _defaultDio() {
    final base = AppEnv.apiBaseUrl.trim();
    if (base.isNotEmpty) {
      return ApiClient.I.dio;
    }
    // In widget tests (or when running with only local assets), API_BASE_URL is
    // often unset; downloading absolute URLs should still work with a bare Dio.
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/octet-stream'},
      ),
    );
  }

  Future<File> cacheMascot(
    MascotConfig mascot, {
    bool forceRefresh = false,
  }) async {
    final mascotId = mascot.id.trim();
    if (mascotId.isEmpty) {
      throw MascotCacheException('Mascot id is required for caching.');
    }

    if (!forceRefresh) {
      final existingPath = await getCachedPath(mascotId);
      if (existingPath != null) {
        return File(existingPath);
      }
    } else {
      await deleteCachedMascot(mascotId);
    }

    final sourceMascot = await _resolveDownloadSource(
      mascot,
      forceRefresh: forceRefresh,
    );
    final assetRef = sourceMascot.riveAssetUrl.trim();
    if (assetRef.isEmpty) {
      throw MascotCacheException(
        'Missing rive asset reference for mascot "$mascotId".',
      );
    }

    final cacheDir = await _ensureCacheDir();
    final target = File(
      p.join(cacheDir.path, '${_safeFileName(mascotId)}.riv.enc'),
    );
    final candidates = await _candidateUrls(assetRef);

    Object? lastError;
    if (candidates.isNotEmpty) {
      for (final url in candidates) {
        try {
          final bytes = await _downloadBytes(url);
          _validateRive(bytes);
          await _writeEncryptedFile(target, mascotId, bytes);
          await pruneCache();
          return target;
        } catch (err) {
          lastError = err;
        }
      }
    }

    throw MascotCacheException(
      'Failed to cache mascot "$mascotId" from "$assetRef"${lastError == null ? '' : ': $lastError'}',
    );
  }

  Future<void> deleteCachedMascot(String mascotId) async {
    final id = mascotId.trim();
    if (id.isEmpty) return;

    final cacheDir = await _ensureCacheDir();
    final safeId = _safeFileName(id);
    final candidates = <File>[
      File(p.join(cacheDir.path, '$safeId.riv.enc')),
      File(p.join(cacheDir.path, '$safeId.riv')),
    ];

    final deletedPaths = <String>[];
    for (final file in candidates) {
      try {
        if (await file.exists()) {
          deletedPaths.add(file.path);
          await file.delete();
        }
      } catch (_) {
        // Best effort cleanup only.
      }
    }

    await _notifyDeletedPaths(deletedPaths);
  }

  Future<bool> isCached(String mascotId) async =>
      (await getCachedPath(mascotId)) != null;

  Future<String?> getCachedPath(String mascotId) async {
    final id = mascotId.trim();
    if (id.isEmpty) return null;
    final cacheDir = await _ensureCacheDir();
    final safeId = _safeFileName(id);

    final encryptedFile = File(p.join(cacheDir.path, '$safeId.riv.enc'));
    if (await encryptedFile.exists()) {
      await _touchFile(encryptedFile);
      return encryptedFile.path;
    }

    final legacyPlaintextFile = File(p.join(cacheDir.path, '$safeId.riv'));
    if (!await legacyPlaintextFile.exists()) return null;

    try {
      final migratedFile = await _migrateLegacyPlaintextFile(
        id,
        legacyPlaintextFile,
      );
      await _touchFile(migratedFile);
      return migratedFile.path;
    } catch (_) {
      // Leave the legacy file untouched; a later sync can retry migration.
    }
    return null;
  }

  Future<void> preloadMascots(List<String> mascotIds) async {
    final ids = mascotIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    for (var i = 0; i < ids.length; i += _defaultConcurrentDownloads) {
      final batch = ids.skip(i).take(_defaultConcurrentDownloads).toList();
      await Future.wait(batch.map(_preloadSingleMascot), eagerError: false);
    }
  }

  Future<void> preloadMascotConfigs(List<MascotConfig> mascots) async {
    if (mascots.isEmpty) return;
    for (var i = 0; i < mascots.length; i += _defaultConcurrentDownloads) {
      final batch = mascots.skip(i).take(_defaultConcurrentDownloads).toList();
      await Future.wait(
        batch.map((mascot) async {
          try {
            await cacheMascot(mascot);
          } catch (_) {
            // Continue preloading remaining mascots.
          }
        }),
        eagerError: false,
      );
    }
  }

  Future<void> pruneCache() async {
    final dir = await _ensureCacheDir();
    final now = DateTime.now();
    final survivors = <_CacheFile>[];
    final deletedPaths = <String>[];

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File ||
          (!entity.path.endsWith('.riv') &&
              !entity.path.endsWith('.riv.enc'))) {
        continue;
      }
      try {
        final stat = await entity.stat();
        final age = now.difference(stat.modified);
        if (age > _maxAge) {
          deletedPaths.add(entity.path);
          await entity.delete();
          continue;
        }
        survivors.add(_CacheFile(entity, stat.modified));
      } catch (_) {
        // Ignore inaccessible entries.
      }
    }

    if (survivors.length <= _maxCacheFiles) return;

    survivors.sort((a, b) => a.modified.compareTo(b.modified));
    final overflow = survivors.length - _maxCacheFiles;
    for (var i = 0; i < overflow; i++) {
      try {
        deletedPaths.add(survivors[i].file.path);
        await survivors[i].file.delete();
      } catch (_) {
        // Ignore delete failures.
      }
    }

    await _notifyDeletedPaths(deletedPaths);
  }

  Future<void> _preloadSingleMascot(String mascotId) async {
    if (await isCached(mascotId)) return;
    final mascot = await _fetchMascotById(mascotId);
    if (mascot == null) return;
    try {
      await cacheMascot(mascot);
    } catch (_) {
      // Ignore preload errors to keep this best-effort.
    }
  }

  Future<MascotConfig?> _fetchMascotById(String mascotId) async {
    try {
      final res = await _dio.get(
        '/rive-elements/$mascotId',
        options: Options(extra: const {'skipAuth': true}),
      );
      final record = _extractMascotRecord(res.data);
      if (record == null) return null;
      return RiveElementDto.fromJson(record).toMascotConfig();
    } catch (_) {
      return null;
    }
  }

  Future<MascotConfig> _resolveDownloadSource(
    MascotConfig mascot, {
    required bool forceRefresh,
  }) async {
    final assetRef = mascot.riveAssetUrl.trim();
    if (_canDownloadDirectly(assetRef) &&
        (!forceRefresh || !_looksLikeLocalPath(assetRef))) {
      return mascot;
    }

    final fetched = await _fetchMascotById(mascot.id.trim());
    if (fetched != null && _canDownloadDirectly(fetched.riveAssetUrl.trim())) {
      return fetched;
    }

    return mascot;
  }

  Future<Directory> _ensureCacheDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'mascots'));
    if (await dir.exists()) return dir;
    return dir.create(recursive: true);
  }

  bool _canDownloadDirectly(String assetRef) {
    return assetRef.isNotEmpty &&
        !assetRef.startsWith('assets/') &&
        !_looksLikeLocalPath(assetRef);
  }

  bool _looksLikeLocalPath(String value) {
    return value.startsWith('/') ||
        value.startsWith('./') ||
        value.startsWith('../') ||
        value.startsWith('file://');
  }

  Map<String, dynamic>? _extractMascotRecord(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final mascot = payload['mascot'];
      if (mascot is Map<String, dynamic>) return mascot;
      if (mascot is Map) return mascot.cast<String, dynamic>();

      final data = payload['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return data.cast<String, dynamic>();

      return payload;
    }
    if (payload is Map) return payload.cast<String, dynamic>();
    return null;
  }

  Future<List<String>> _candidateUrls(String assetRef) async {
    final value = assetRef.trim();
    if (value.isEmpty) return const [];
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return [value];
    }
    if (value.startsWith('assets/')) {
      return const [];
    }
    if (value.startsWith('file://')) {
      return [value];
    }

    await AppEnv.load();
    final rawBase = AppEnv.apiBaseUrl.trim();
    if (rawBase.isEmpty) return const [];
    final base = rawBase.endsWith('/')
        ? rawBase.substring(0, rawBase.length - 1)
        : rawBase;

    final candidates = <String>[];
    final relative = value.startsWith('/') ? value.substring(1) : value;
    final encoded = Uri.encodeComponent(value);

    if (value.startsWith('/')) {
      candidates.add('$base$value');
    } else {
      candidates.add('$base/$relative');
    }

    candidates.add('$base/rive-elements/$encoded');
    candidates.add('$base/files/$encoded');
    candidates.add('$base/media/$encoded');
    candidates.add('$base/uploads/$relative');
    candidates.add('$base/assets/$relative');

    final seen = <String>{};
    final unique = <String>[];
    for (final item in candidates) {
      if (item.isEmpty || !seen.add(item)) continue;
      unique.add(item);
    }
    return unique;
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final res = await _dio.get(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        extra: const {'skipAuth': true},
      ),
    );

    final data = res.data;
    if (data is Uint8List && data.isNotEmpty) return data;
    if (data is List<int> && data.isNotEmpty) return Uint8List.fromList(data);
    throw MascotCacheException('Downloaded mascot file is empty: $url');
  }

  void _validateRive(Uint8List bytes) {
    try {
      final byteData = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      RiveFile.import(byteData);
    } catch (err) {
      throw MascotCacheException('Invalid .riv data: $err');
    }
  }

  Future<void> _writeEncryptedFile(
    File target,
    String mascotId,
    Uint8List plainBytes,
  ) async {
    final encryptedBytes = await _cryptoService.encrypt(plainBytes, mascotId);
    final tempPath = '${target.path}.tmp';
    final tmp = File(tempPath);
    await tmp.writeAsBytes(encryptedBytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  Future<File> _migrateLegacyPlaintextFile(
    String mascotId,
    File legacyFile,
  ) async {
    final plainBytes = await legacyFile.readAsBytes();
    _validateRive(plainBytes);

    final encryptedFile = File(
      p.join(legacyFile.parent.path, '${_safeFileName(mascotId)}.riv.enc'),
    );
    await _writeEncryptedFile(encryptedFile, mascotId, plainBytes);
    await legacyFile.delete();
    return encryptedFile;
  }

  Future<void> _touchFile(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {
      // Best effort; stale timestamps are acceptable.
    }
  }

  Future<void> _notifyDeletedPaths(List<String> deletedPaths) async {
    if (deletedPaths.isEmpty) return;
    final callback = _onFilesDeleted;
    if (callback == null) return;
    await callback(deletedPaths);
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}

class _CacheFile {
  _CacheFile(this.file, this.modified);
  final File file;
  final DateTime modified;
}
