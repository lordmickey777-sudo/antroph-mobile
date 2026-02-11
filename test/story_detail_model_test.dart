import 'dart:convert';

import 'package:antroph_mobile/features/story/models/story_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StoryDetailDto parses example schema', () {
    const jsonStr = '''
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "category_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "mascot_id": "toad_mascot",
      "mascot": {
        "id": "toad_mascot",
        "name": "Toad",
        "rive_asset_url": "https://cdn.example.com/mascots/toad.riv",
        "state_machine": "FaceSm",
        "fallback_asset": "default_face",
        "expression_config": {
          "happy": { "eyeExpression": 2, "mouthOpen": 60 }
        }
      },
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
    expect(dto.mascotId, 'toad_mascot');
    expect(dto.mascot, isNotNull);
    expect(dto.mascot!.name, 'Toad');
    expect(dto.mascot!.expressions['happy']?.eyeExpression, 2);
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
