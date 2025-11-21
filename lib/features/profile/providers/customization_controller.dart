import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_settings_repository.dart';
import '../models/ai_settings.dart';

class CustomizationController extends AsyncNotifier<AiSettings> {
  late final AiSettingsRepository _repo;
  bool _isSaving = false;

  bool get isSaving => _isSaving;

  @override
  Future<AiSettings> build() async {
    _repo = AiSettingsRepository();
    return _repo.fetchSettings();
  }

  Future<void> saveSettings(AiSettings settings) async {
    _setSaving(true);
    try {
      final updated = await _repo.updateSettings(settings);
      state = AsyncValue.data(updated);
    } finally {
      _setSaving(false);
    }
  }

  void _setSaving(bool saving) {
    _isSaving = saving;
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(current);
    }
  }
}

final customizationControllerProvider =
    AsyncNotifierProvider<CustomizationController, AiSettings>(
      CustomizationController.new,
    );
