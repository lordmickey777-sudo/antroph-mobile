import 'package:antroph_mobile/features/story/models/mascot_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MascotConfig parses expression_config and defaults', () {
    final mascot = MascotConfig.fromJson({
      'id': 'robot_1',
      'name': 'Cosmo',
      'rive_asset_url': 'https://cdn.example.com/cosmo.riv',
      'expression_config': {
        'happy': {'eyeExpression': 3, 'mouthOpen': 80},
      },
    });

    expect(mascot.id, 'robot_1');
    expect(mascot.effectiveStateMachine, MascotConfig.defaultStateMachine);
    expect(mascot.expressions['happy']?.mouthOpen, 80);
    expect(mascot.effectiveFallbackAsset, MascotConfig.defaultFallbackAsset);
  });

  test('MascotConfig maybeFromJson returns null for invalid payload', () {
    expect(MascotConfig.maybeFromJson(null), isNull);
    expect(MascotConfig.maybeFromJson('not-a-map'), isNull);
  });
}
