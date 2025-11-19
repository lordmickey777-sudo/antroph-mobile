import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/robot_pairing_repository.dart';

final robotPairingRepositoryProvider = Provider<RobotPairingRepository>((ref) {
  return RobotPairingRepository();
});
