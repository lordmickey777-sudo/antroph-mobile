import 'dart:convert';

import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StoryDetailDto parses example schema', () {
    const jsonStr = '''
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "category_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "title": "string",
      "description": "string",
      "author": "string",
      "age_rating": 12,
      "tags": ["one", "two"],
      "duration_minutes": 45,
      "difficulty": "medium",
      "is_premium": true,
      "price": 9.99,
      "is_published": true,
      "published_at": "2025-11-12T17:20:32.401Z",
      "created_by_admin_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "created_at": "2025-11-12T17:20:32.401Z",
      "updated_at": "2025-11-12T17:20:32.401Z",
      "tree": {"root": {}},
      "preview_node_ids": ["n1", "n2"]
    }
    ''';
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final dto = StoryDetailDto.fromJson(map);
    expect(dto.id.isNotEmpty, true);
    expect(dto.categoryId.isNotEmpty, true);
    expect(dto.title, 'string');
    expect(dto.ageRating, 12);
    expect(dto.tags.length, 2);
    expect(dto.durationMinutes, 45);
    expect(dto.isPremium, true);
    expect(dto.price, 9.99);
    expect(dto.isPublished, true);
    expect(dto.publishedAt, isNotNull);
    expect(dto.tree.isNotEmpty, true);
    expect(dto.previewNodeIds, ['n1', 'n2']);
  });
}
