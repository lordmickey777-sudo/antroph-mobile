import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../data/profile_repository.dart';
import '../models/user_profile.dart';
import '../../../core/network/error_formatter.dart';
import '../../../core/auth/state/auth_state.dart';

/// Async state of the user's profile. Null indicates not yet loaded / no profile.
class ProfileController extends AsyncNotifier<UserProfile?> {
  late final ProfileRepository _repo;
  final _picker = ImagePicker();

  // Previously debounced; now we perform immediate checks and cancel in-flight requests.
  Timer? _debounce;
  CancelToken? _usernameCancelToken;
  UsernameAvailability? _usernameAvailability;
  UsernameAvailability? get usernameAvailability => _usernameAvailability;
  bool _isCheckingUsername = false;
  bool get isCheckingUsername => _isCheckingUsername;

  @override
  Future<UserProfile?> build() async {
    _repo = ProfileRepository();
    // Load full profile from backend when authenticated; fall back to auth state minimal info.
    final authUser = ref.watch(authControllerProvider).value;
    if (authUser == null) return null;
    try {
      final p = await _repo.getMyProfile();
      return p;
    } catch (_) {
      // Fallback: synthesize minimal profile from auth state so UI can still prefill some fields.
      return UserProfile(
        id: authUser.id,
        email: authUser.email,
        username: authUser.username,
        displayName: authUser.displayName,
        avatarUrl: null,
        bio: null,
        dateOfBirth: null,
        timezone: null,
        language: null,
        isCompleted: false,
      );
    }
  }

  /// Upload a new avatar picked from gallery or camera.
  Future<void> pickAndUploadAvatar({ImageSource source = ImageSource.gallery}) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 512, imageQuality: 75);
      if (file == null) return; // user canceled

      final url = await _repo.uploadAvatar(
        filePath: file.path,
        fileName: file.name,
      );

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
          isCompleted: current.isCompleted,
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

  /// Immediately check username availability on each change (cancels previous request).
  void checkUsernameImmediate(String username) {
    // Cancel any pending debounce or in-flight request
    _debounce?.cancel();
    _usernameCancelToken?.cancel('replaced');

    if (username.isEmpty) {
      _usernameAvailability = null;
      _isCheckingUsername = false;
      state = AsyncValue.data(state.value);
      return;
    }

    // Reflect checking state instantly for responsive UX
    _isCheckingUsername = true;
    state = AsyncValue.data(state.value);

    final token = CancelToken();
    _usernameCancelToken = token;

    () async {
      try {
        final result = await _repo.checkUsernameAvailability(username, cancelToken: token);
        // If another request has started since, ignore this result
        if (_usernameCancelToken != token) return;
        _usernameAvailability = result;
      } catch (e) {
        // Ignore cancellations, swallow other errors to keep UX smooth
      } finally {
        if (_usernameCancelToken == token) {
          _isCheckingUsername = false;
          state = AsyncValue.data(state.value);
        }
      }
    }();
  }

  List<String> missingFields(UserProfile? profile) {
    final p = profile;
    if (p?.isCompleted == true) return [];
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

  /// Soft delete the current account via /users/me/account then logout locally.
  Future<String> deleteAccount() async {
    try {
      final message = await _repo.deleteAccount();
      // Clear local state first to avoid showing stale data.
      state = const AsyncValue.data(null);
      await ref.read(authControllerProvider.notifier).logout();
      return message;
    } on ApiError catch (e) {
      throw e;
    } catch (e) {
      throw ApiError(message: e.toString());
    }
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(
  ProfileController.new,
);
