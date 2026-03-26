import 'dart:convert';
import 'dart:io';

import 'package:antroph_mobile/core/db/app_database.dart';
import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:antroph_mobile/features/story/services/mascot_cache_service.dart';
import 'package:antroph_mobile/features/story/services/rive_registry_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiveRegistryService', () {
    late AppDatabase database;
    late Directory tempDir;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('rive-registry-test');
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('clears stale local path when cached file is missing', () async {
      await database
          .into(database.riveElements)
          .insert(
            RiveElementsCompanion.insert(
              id: 'missing-element',
              name: 'Missing Element',
              category: 'story',
              stateMachine: const Value('FaceSm'),
              artboard: const Value.absent(),
              fallbackAsset: const Value.absent(),
              expressionConfig: const Value('{}'),
              tags: const Value('[]'),
              displayOrder: const Value(0),
              isActive: const Value(true),
              contentHash: const Value.absent(),
              localRivPath: Value('${tempDir.path}/missing.riv.enc'),
              syncedAt: Value(DateTime.now().toUtc()),
            ),
          );

      final service = RiveRegistryService(
        database: database,
        mascotCacheService: _FakeMascotCacheService(),
        dio: Dio(),
      );

      final result = await service.getLocalMascotConfig('missing-element');
      expect(result, isNull);

      final row = await (database.select(
        database.riveElements,
      )..where((tbl) => tbl.id.equals('missing-element'))).getSingle();
      expect(row.localRivPath, isNull);
    });

    test(
      'cacheMascotConfig upserts local metadata for cached mascots',
      () async {
        final cachedFile = File('${tempDir.path}/cached.riv.enc');
        await cachedFile.writeAsBytes(const [1, 2, 3], flush: true);

        final service = RiveRegistryService(
          database: database,
          mascotCacheService: _FakeMascotCacheService(fileToReturn: cachedFile),
          dio: Dio(),
        );

        final mascot = MascotConfig(
          id: 'cached-element',
          name: 'Aura',
          riveAssetUrl: 'https://example.com/aura.riv',
          stateMachine: 'FaceSm',
          fallbackAsset: MascotConfig.defaultFallbackAsset,
          expressions: const {
            'happy': ExpressionParams(eyeExpression: 1, headTilt: 3),
          },
        );

        await service.cacheMascotConfig(mascot);

        final row = await (database.select(
          database.riveElements,
        )..where((tbl) => tbl.id.equals('cached-element'))).getSingle();
        expect(row.localRivPath, cachedFile.path);
        expect(row.name, 'Aura');
        expect(row.category, 'story');

        final expressionConfig =
            jsonDecode(row.expressionConfig) as Map<String, dynamic>;
        expect(expressionConfig['happy'], isA<Map<String, dynamic>>());
        expect(
          (expressionConfig['happy'] as Map<String, dynamic>)['eyeExpression'],
          1,
        );
      },
    );

    test(
      'clearLocalPathsForFiles only clears matching registry entries',
      () async {
        await database
            .into(database.riveElements)
            .insert(
              RiveElementsCompanion.insert(
                id: 'one',
                name: 'One',
                category: 'story',
                stateMachine: const Value('FaceSm'),
                expressionConfig: const Value('{}'),
                tags: const Value('[]'),
                displayOrder: const Value(0),
                isActive: const Value(true),
                localRivPath: Value('${tempDir.path}/one.riv.enc'),
                syncedAt: Value(DateTime.now().toUtc()),
              ),
            );
        await database
            .into(database.riveElements)
            .insert(
              RiveElementsCompanion.insert(
                id: 'two',
                name: 'Two',
                category: 'story',
                stateMachine: const Value('FaceSm'),
                expressionConfig: const Value('{}'),
                tags: const Value('[]'),
                displayOrder: const Value(0),
                isActive: const Value(true),
                localRivPath: Value('${tempDir.path}/two.riv.enc'),
                syncedAt: Value(DateTime.now().toUtc()),
              ),
            );

        final service = RiveRegistryService(
          database: database,
          mascotCacheService: _FakeMascotCacheService(),
          dio: Dio(),
        );

        await service.clearLocalPathsForFiles(['${tempDir.path}/one.riv.enc']);

        final first = await (database.select(
          database.riveElements,
        )..where((tbl) => tbl.id.equals('one'))).getSingle();
        final second = await (database.select(
          database.riveElements,
        )..where((tbl) => tbl.id.equals('two'))).getSingle();

        expect(first.localRivPath, isNull);
        expect(second.localRivPath, '${tempDir.path}/two.riv.enc');
      },
    );
  });
}

class _FakeMascotCacheService extends MascotCacheService {
  _FakeMascotCacheService({this.fileToReturn}) : super(dio: Dio());

  final File? fileToReturn;

  @override
  Future<File> cacheMascot(
    MascotConfig mascot, {
    bool forceRefresh = false,
  }) async {
    final file = fileToReturn;
    if (file == null) {
      throw MascotCacheException('No fake cache file configured.');
    }
    return file;
  }

  @override
  Future<String?> getCachedPath(String mascotId) async {
    return fileToReturn?.path;
  }
}
