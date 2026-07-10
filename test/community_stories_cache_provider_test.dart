import 'dart:async';
import 'dart:convert';

import 'package:antroph_mobile/core/auth/models/user.dart';
import 'package:antroph_mobile/core/auth/state/auth_state.dart';
import 'package:antroph_mobile/features/community_stories/data/community_stories_cache.dart';
import 'package:antroph_mobile/features/community_stories/data/community_stories_repository.dart';
import 'package:antroph_mobile/features/community_stories/models/community_story_model.dart';
import 'package:antroph_mobile/features/community_stories/providers/community_stories_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('expired and corrupt community caches are removed', () async {
    final expiredAt =
        DateTime.now().millisecondsSinceEpoch -
        CommunityStoriesCacheService.maxAge.inMilliseconds -
        1;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'community_stories_cache_v2_expired': jsonEncode(<Object>[
        _story('https://old.example/cover.jpg').toJson(),
      ]),
      'community_stories_cache_ts_v2_expired': expiredAt,
      'community_stories_cache_v2_corrupt': '{not-json',
      'community_stories_cache_ts_v2_corrupt':
          DateTime.now().millisecondsSinceEpoch,
    });

    expect(
      await CommunityStoriesCacheService.load(categoryId: 'expired'),
      isNull,
    );
    expect(
      await CommunityStoriesCacheService.load(categoryId: 'corrupt'),
      isNull,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('community_stories_cache_v2_expired'), isFalse);
    expect(prefs.containsKey('community_stories_cache_ts_v2_expired'), isFalse);
    expect(prefs.containsKey('community_stories_cache_v2_corrupt'), isFalse);
    expect(prefs.containsKey('community_stories_cache_ts_v2_corrupt'), isFalse);
  });

  test('loading the v2 cache purges legacy story and Rive entries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'community_stories_cache_v1_my_stories': '[]',
      'community_stories_cache_ts_v1_my_stories':
          DateTime.now().millisecondsSinceEpoch,
      'rive_elements_cache_v1_all': '[]',
      'rive_elements_cache_ts_v1_all': DateTime.now().millisecondsSinceEpoch,
    });

    await CommunityStoriesCacheService.load(categoryId: 'missing');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.contains('_cache_v1')), isEmpty);
  });

  test('my stories publishes a fresh cover URL after cached data', () async {
    const userId = 'user-1';
    await CommunityStoriesCacheService.save(<CommunityStoryDto>[
      _story('https://old.example/cover.jpg'),
    ], categoryId: 'my_stories:$userId');

    final repository = _ControlledCommunityRepository();
    final container = ProviderContainer(
      overrides: [
        communityStoriesRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController(userId)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final freshState = Completer<List<CommunityStoryDto>>();
    final subscription = container.listen(myStoriesProvider, (_, next) {
      final stories = next.asData?.value;
      if (stories?.firstOrNull?.coverImageUrl ==
              'https://fresh.example/cover.jpg' &&
          !freshState.isCompleted) {
        freshState.complete(stories);
      }
    });
    addTearDown(subscription.close);

    final cached = await container.read(myStoriesProvider.future);
    expect(cached.single.coverImageUrl, 'https://old.example/cover.jpg');

    repository.myStories.complete(<CommunityStoryDto>[
      _story('https://fresh.example/cover.jpg'),
    ]);
    final fresh = await freshState.future.timeout(const Duration(seconds: 2));

    expect(fresh.single.coverImageUrl, 'https://fresh.example/cover.jpg');
    expect(repository.myStoriesCalls, 1);
  });

  test(
    'community browse publishes a fresh cover URL after cached data',
    () async {
      await CommunityStoriesCacheService.save(<CommunityStoryDto>[
        _story('https://old.example/cover.jpg'),
      ], categoryId: 'all:approved_published_v1');

      final repository = _ControlledCommunityRepository();
      final container = ProviderContainer(
        overrides: [
          communityStoriesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = communityBrowseProvider(null);
      final freshState = Completer<List<CommunityStoryDto>>();
      final subscription = container.listen(provider, (_, next) {
        final stories = next.asData?.value;
        if (stories?.firstOrNull?.coverImageUrl ==
                'https://fresh.example/cover.jpg' &&
            !freshState.isCompleted) {
          freshState.complete(stories);
        }
      });
      addTearDown(subscription.close);

      final cached = await container.read(provider.future);
      expect(cached.single.coverImageUrl, 'https://old.example/cover.jpg');

      repository.browseStories.complete(<CommunityStoryDto>[
        _story('https://fresh.example/cover.jpg'),
      ]);
      final fresh = await freshState.future.timeout(const Duration(seconds: 2));

      expect(fresh.single.coverImageUrl, 'https://fresh.example/cover.jpg');
      expect(repository.browseCalls, 1);
    },
  );
}

CommunityStoryDto _story(String coverImageUrl) {
  final now = DateTime(2026, 7, 10);
  return CommunityStoryDto(
    id: 'story-1',
    title: 'A community story',
    coverImageUrl: coverImageUrl,
    moderationStatus: 'approved',
    isPublished: true,
    createdAt: now,
    updatedAt: now,
  );
}

class _ControlledCommunityRepository extends CommunityStoriesRepository {
  _ControlledCommunityRepository() : super(dio: Dio());

  final myStories = Completer<List<CommunityStoryDto>>();
  final browseStories = Completer<List<CommunityStoryDto>>();
  int myStoriesCalls = 0;
  int browseCalls = 0;

  @override
  Future<List<CommunityStoryDto>> fetchMyStories({
    int page = 1,
    int pageSize = 20,
  }) {
    myStoriesCalls += 1;
    return myStories.future;
  }

  @override
  Future<List<CommunityStoryDto>> browseCommunityStories({
    int page = 1,
    int pageSize = 20,
    String? categoryId,
  }) {
    browseCalls += 1;
    return browseStories.future;
  }
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.userId);

  final String userId;

  @override
  Future<AuthUser?> build() async => AuthUser(
    id: userId,
    email: '$userId@example.com',
    emailVerificationRequired: false,
  );
}
