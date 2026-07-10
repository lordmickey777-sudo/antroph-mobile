import 'package:antroph_mobile/features/community_stories/models/community_story_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only approved and published community stories are publicly visible',
    () {
      expect(
        _story(status: 'approved', isPublished: true).isApprovedAndPublished,
        isTrue,
      );
      expect(
        _story(status: 'approved', isPublished: false).isApprovedAndPublished,
        isFalse,
      );
      expect(
        _story(status: 'pending', isPublished: true).isApprovedAndPublished,
        isFalse,
      );
      expect(
        _story(status: 'rejected', isPublished: false).isApprovedAndPublished,
        isFalse,
      );
    },
  );
}

CommunityStoryDto _story({required String status, required bool isPublished}) {
  final now = DateTime(2026, 7, 10);
  return CommunityStoryDto(
    id: '$status-$isPublished',
    title: 'Community story',
    moderationStatus: status,
    isPublished: isPublished,
    createdAt: now,
    updatedAt: now,
  );
}
