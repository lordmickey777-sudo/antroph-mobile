import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_repository.dart';
import '../models/user_profile.dart';
import '../../../core/network/error_formatter.dart';
import '../../../core/auth/state/auth_state.dart';

/// Async state of the user's profile. Null indicates not yet loaded / no profile.
class ProfileController extends AsyncNotifier<UserProfile?> {
  late final ProfileRepository _repo;
  final _picker = ImagePicker();

  // Debounce timer for username availability check
  Timer? _debounce;
  UsernameAvailability? _usernameAvailability;
  UsernameAvailability? get usernameAvailability => _usernameAvailability;

  @override
  Future<UserProfile?> build() async {
    _repo = ProfileRepository();
    // We don't have a GET /users/me documented; derive initial profile from auth state where possible.
    final authUser = ref.watch(authControllerProvider).value;
    if (authUser == null) return null;
    return UserProfile(
      id: authUser.id,
      email: authUser.email,
      username: authUser.username,
      displayName: authUser.displayName,
      avatarUrl: null, // unknown until user updates
      bio: null,
      dateOfBirth: null,
      timezone: null,
      language: null,
    );
  }

  /// Upload a new avatar picked from gallery or camera.
  Future<void> pickAndUploadAvatar({ImageSource source = ImageSource.gallery}) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 512, imageQuality: 75);
      if (file == null) return; // user canceled
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final url = await _repo.uploadAvatar(avatarBase64: base64Data);
      // Update state with new avatar url
      final current = state.value;
      if (current != null) {
        final updated = UserProfile(
          id: current.id,
          email: current.email,
          username: current.username,
          displayName: current.displayName,
          avatarUrl: url.isNotEmpty ? url : current.avatarUrl,
          bio: current.bio,
          dateOfBirth: current.dateOfBirth,
          timezone: current.timezone,
          language: current.language,
        );
        state = AsyncValue.data(updated);
      }
    } catch (e, st) {
      if (e is ApiError) {
        state = AsyncValue.error(e.message, st);
      } else {
        state = AsyncValue.error(e.toString(), st);
      }
    }
  }

  /// Update profile fields.
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? bio,
    DateTime? dateOfBirth,
    String? timezone,
    String? language,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repo.updateProfile(
        username: username,
        displayName: displayName,
        bio: bio,
        dateOfBirth: dateOfBirth,
        timezone: timezone,
        language: language,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      if (e is ApiError) {
        state = AsyncValue.error(e.message, st);
      } else {
        state = AsyncValue.error(e.toString(), st);
      }
    }
  }

  /// Debounced username availability check.
  void checkUsernameDebounced(String username) {
    _debounce?.cancel();
    if (username.isEmpty) {
      _usernameAvailability = null;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await _repo.checkUsernameAvailability(username);
        _usernameAvailability = result;
        // Force a rebuild by assigning same state
        state = AsyncValue.data(state.value);
      } catch (_) {
        // swallow errors for availability (keep UX smooth)
      }
    });
  }

  List<String> missingFields(UserProfile? profile) {
    final p = profile;
    if (p == null) return ['profile'];
    final missing = <String>[];
    if (p.avatarUrl == null || p.avatarUrl!.isEmpty) missing.add('avatar');
    if (p.username == null || p.username!.isEmpty) missing.add('username');
    if (p.displayName == null || p.displayName!.isEmpty) missing.add('display name');
    if (p.dateOfBirth == null) missing.add('date of birth');
    if (p.language == null || p.language!.isEmpty) missing.add('language');
    if (p.timezone == null || p.timezone!.isEmpty) missing.add('timezone');
    return missing;
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(
  ProfileController.new,
);
