import 'dart:convert';

import 'package:antroph_mobile/features/story/models/story_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StoriesHomeResponse parses sections and items', () {
    const jsonStr = '''
    {
      "sections": [
        {
          "title": "Recommended",
          "items": [
            {
              "title": "AI Story",
              "subtitle": "Smartest AI",
              "image": "assets/images/default.png",
              "users": 123,
              "views": 456,
              "rive_element_id": "space_robot",
              "rive_element": {
                "id": "space_robot",
                "name": "Cosmo",
                "category": "character",
                "rive_asset_url": "https://cdn.example.com/mascots/cosmo.riv",
                "state_machine": "FaceSm"
              }
            }
          ]
        },
        {
          "title": "Featured Collection",
          "items": [
            {"title": "Space Adventure", "subtitle": "Explore the universe", "image": "assets/images/space.png", "users": 78, "views": 90}
          ]
        }
      ]
    }
    ''';
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final parsed = StoriesHomeResponse.fromJson(map);
    expect(parsed.sections.length, 2);
    expect(parsed.sections.first.title, 'Recommended');
    expect(parsed.sections.first.items.first.title, 'AI Story');
    expect(parsed.sections.first.items.first.users, 123);
    expect(parsed.sections.first.items.first.riveElementId, 'space_robot');
    expect(parsed.sections.first.items.first.riveElement?.name, 'Cosmo');
    expect(parsed.sections.last.items.first.views, 90);
  });
}
