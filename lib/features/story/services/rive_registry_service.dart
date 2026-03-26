import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/analytics/posthog_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/api_client.dart';
import '../../community_stories/models/rive_element_model.dart';
import '../models/mascot_model.dart';
import '../models/story_detail.dart';
import 'mascot_cache_service.dart';

class RiveRegistryService {
  RiveRegistryService({
    required AppDatabase database,
    MascotCacheService? mascotCacheService,
    Dio? dio,
  }) : _database = database,
       _mascotCacheService = mascotCacheService ?? MascotCacheService(dio: dio),
       _dio = dio ?? ApiClient.I.dio;

  final AppDatabase _database;
  final MascotCacheService _mascotCacheService;
  final Dio _dio;
  Future<void>? _manifestSyncInFlight;
  DateTime? _lastManifestSyncAt;

  static const Duration _manifestSyncMinInterval = Duration(minutes: 5);

  Future<MascotConfig?> getLocalMascotConfig(String elementId) async {
    final id = elementId.trim();
    if (id.isEmpty) return null;

    final row = await (_database.select(
      _database.riveElements,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final path = row.localRivPath?.trim() ?? '';
    if (path.isEmpty) {
      return null;
    }

    if (!await File(path).exists()) {
      await _clearLocalPath(id);
      return null;
    }

    return _toMascotConfig(row);
  }

  Future<StoryDetailDto> attachLocalMascot(StoryDetailDto detail) async {
    final riveElementId = detail.riveElementId?.trim() ?? '';
    if (riveElementId.isEmpty) return detail;

    final localConfig = await getLocalMascotConfig(riveElementId);
    if (localConfig == null) return detail;
    return detail.copyWith(resolvedMascotConfig: localConfig);
  }

  Future<void> cacheElementFromDetail(StoryDetailDto detail) async {
    final riveElement = detail.riveElement;
    if (riveElement == null) return;
    await cacheElementDto(riveElement);
  }

  Future<void> cacheElementDto(RiveElementDto dto) async {
    final id = dto.id.trim();
    if (id.isEmpty) return;

    String? localPath;
    try {
      final cached = await _mascotCacheService.cacheMascot(
        dto.toMascotConfig(),
      );
      localPath = cached.path;
    } catch (error, stackTrace) {
      Log.i.w('[RiveRegistry] Failed to cache dto element ${dto.id}: $error');
      Log.i.d(stackTrace.toString());
      unawaited(
        PostHogService.capture(
          'rive_cache_write_failed',
          properties: {'element_id': dto.id, 'source': 'dto'},
        ),
      );
      localPath = await _mascotCacheService.getCachedPath(id);
    }

    await _upsertFromDto(dto, localRivPath: localPath);
    await reconcileLocalCache();
  }

  Future<void> cacheMascotConfig(MascotConfig mascot) async {
    final id = mascot.id.trim();
    if (id.isEmpty) return;

    String? localPath;
    try {
      final cached = await _mascotCacheService.cacheMascot(mascot);
      localPath = cached.path;
    } catch (error, stackTrace) {
      Log.i.w(
        '[RiveRegistry] Failed to cache mascot config ${mascot.id}: $error',
      );
      Log.i.d(stackTrace.toString());
      unawaited(
        PostHogService.capture(
          'rive_cache_write_failed',
          properties: {'element_id': mascot.id, 'source': 'mascot_config'},
        ),
      );
      localPath = await _mascotCacheService.getCachedPath(id);
    }

    await _upsertFromMascotConfig(mascot, localRivPath: localPath);
    await reconcileLocalCache();
  }

  Future<void> ensureElementById(String elementId) async {
    final id = elementId.trim();
    if (id.isEmpty) return;

    final res = await _dio.get(
      '/rive-elements/$id',
      options: Options(extra: const {'skipAuth': true}),
    );
    final payload = res.data;
    if (payload is! Map<String, dynamic>) return;

    final dto = RiveElementDto.fromJson(payload);
    await cacheElementDto(dto);
  }

  Future<void> syncManifest({bool force = false}) async {
    if (!force) {
      final inFlight = _manifestSyncInFlight;
      if (inFlight != null) {
        await inFlight;
        return;
      }

      final lastSyncAt = _lastManifestSyncAt;
      if (lastSyncAt != null &&
          DateTime.now().toUtc().difference(lastSyncAt) <
              _manifestSyncMinInterval) {
        return;
      }
    }

    final future = _runManifestSync();
    _manifestSyncInFlight = future;
    try {
      await future;
      _lastManifestSyncAt = DateTime.now().toUtc();
    } catch (error, stackTrace) {
      Log.i.w('[RiveRegistry] Manifest sync failed: $error');
      Log.i.d(stackTrace.toString());
      unawaited(
        PostHogService.capture(
          'rive_manifest_sync_failed',
          properties: const {'scope': 'startup_or_background'},
        ),
      );
      rethrow;
    } finally {
      if (identical(_manifestSyncInFlight, future)) {
        _manifestSyncInFlight = null;
      }
    }
  }

  Future<void> reconcileLocalCache() async {
    final rows = await _database.select(_database.riveElements).get();
    for (final row in rows) {
      final path = row.localRivPath?.trim() ?? '';
      if (path.isEmpty) continue;
      if (await File(path).exists()) continue;
      await _clearLocalPath(row.id);
    }
  }

  Future<void> clearLocalPathsForFiles(List<String> paths) async {
    final normalized = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return;

    await (_database.update(_database.riveElements)
          ..where((tbl) => tbl.localRivPath.isIn(normalized)))
        .write(const RiveElementsCompanion(localRivPath: Value(null)));
  }

  Future<void> _runManifestSync() async {
    await reconcileLocalCache();

    final res = await _dio.get(
      '/rive-elements/manifest',
      options: Options(extra: const {'skipAuth': true}),
    );
    final payload = res.data;
    if (payload is! List) return;

    final manifest = <String, _RiveManifestItem>{};
    for (final item in payload) {
      if (item is! Map<String, dynamic>) continue;
      final parsed = _RiveManifestItem.fromJson(item);
      if (parsed.id.isEmpty) continue;
      manifest[parsed.id] = parsed;
    }

    final locals = await _database.select(_database.riveElements).get();
    final localById = {for (final row in locals) row.id: row};

    for (final row in locals) {
      if (manifest.containsKey(row.id)) continue;
      await _deleteLocalEntry(row);
    }

    for (final entry in manifest.entries) {
      final local = localById[entry.key];
      final localPath = local?.localRivPath?.trim() ?? '';
      final hasLocalFile =
          localPath.isNotEmpty && await File(localPath).exists();
      final hashChanged = local?.contentHash != entry.value.contentHash;
      final missing = local == null || !hasLocalFile;
      if (missing || hashChanged) {
        await ensureElementById(entry.key);
      }
    }
  }

  Future<void> _upsertFromDto(
    RiveElementDto dto, {
    String? localRivPath,
  }) async {
    final existing = await (_database.select(
      _database.riveElements,
    )..where((tbl) => tbl.id.equals(dto.id))).getSingleOrNull();

    await _database
        .into(_database.riveElements)
        .insertOnConflictUpdate(
          RiveElementsCompanion(
            id: Value(dto.id),
            name: Value(dto.name),
            category: Value(dto.category),
            stateMachine: Value(dto.stateMachine),
            artboard: Value(dto.artboard),
            fallbackAsset: Value(dto.fallbackAsset),
            expressionConfig: Value(jsonEncode(dto.expressionConfig)),
            tags: Value(jsonEncode(dto.tags)),
            displayOrder: Value(dto.displayOrder),
            isActive: Value(dto.isActive),
            contentHash: Value(dto.contentHash ?? existing?.contentHash),
            localRivPath: Value(localRivPath ?? existing?.localRivPath),
            syncedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> _upsertFromMascotConfig(
    MascotConfig mascot, {
    String? localRivPath,
  }) async {
    final existing = await (_database.select(
      _database.riveElements,
    )..where((tbl) => tbl.id.equals(mascot.id))).getSingleOrNull();

    await _database
        .into(_database.riveElements)
        .insertOnConflictUpdate(
          RiveElementsCompanion(
            id: Value(mascot.id),
            name: Value(
              mascot.name.trim().isEmpty
                  ? (existing?.name ?? mascot.id)
                  : mascot.name,
            ),
            category: Value(existing?.category ?? 'story'),
            stateMachine: Value(mascot.effectiveStateMachine),
            artboard: Value(mascot.artboard),
            fallbackAsset: Value(mascot.fallbackAsset),
            expressionConfig: Value(
              jsonEncode(
                mascot.expressions.map(
                  (key, value) => MapEntry(key, value.toJson()),
                ),
              ),
            ),
            tags: Value(existing?.tags ?? '[]'),
            displayOrder: Value(existing?.displayOrder ?? 0),
            isActive: Value(existing?.isActive ?? true),
            contentHash: Value(existing?.contentHash),
            localRivPath: Value(localRivPath ?? existing?.localRivPath),
            syncedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> _deleteLocalEntry(RiveElement row) async {
    final path = row.localRivPath?.trim() ?? '';
    if (path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best effort cleanup only.
      }
    }

    await (_database.delete(
      _database.riveElements,
    )..where((tbl) => tbl.id.equals(row.id))).go();
  }

  Future<void> _clearLocalPath(String elementId) async {
    final id = elementId.trim();
    if (id.isEmpty) return;

    await (_database.update(_database.riveElements)
          ..where((tbl) => tbl.id.equals(id)))
        .write(const RiveElementsCompanion(localRivPath: Value(null)));
  }

  MascotConfig _toMascotConfig(RiveElement row) {
    final expressions = <String, ExpressionParams>{};
    final rawConfig = row.expressionConfig.trim();
    if (rawConfig.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawConfig);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString().trim();
            final value = entry.value;
            if (key.isEmpty || value is! Map) continue;
            expressions[key] = ExpressionParams.fromJson(
              value.cast<String, dynamic>(),
            );
          }
        }
      } catch (_) {
        // Invalid JSON should not break mascot rendering.
      }
    }

    return MascotConfig(
      id: row.id,
      name: row.name,
      riveAssetUrl: row.localRivPath?.trim().isNotEmpty == true
          ? row.localRivPath!.trim()
          : MascotConfig.defaultFallbackAsset,
      stateMachine: row.stateMachine,
      artboard: row.artboard,
      fallbackAsset: row.fallbackAsset,
      expressions: expressions,
      localAssetPath: row.localRivPath,
    );
  }
}

class _RiveManifestItem {
  const _RiveManifestItem({required this.id, this.contentHash});

  final String id;
  final String? contentHash;

  factory _RiveManifestItem.fromJson(Map<String, dynamic> json) {
    return _RiveManifestItem(
      id: (json['id'] as String?)?.trim() ?? '',
      contentHash: (json['content_hash'] as String?)?.trim(),
    );
  }
}
