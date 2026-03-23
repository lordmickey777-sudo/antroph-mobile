import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repository/auth_repository.dart';
import '../services/email_storage_service.dart';
import '../services/social_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../analytics/posthog_service.dart';
import '../../network/error_formatter.dart';
import '../../network/api_client.dart';
import '../../notifications/push_notification_service.dart';

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });
  bool get isValid => accessToken.isNotEmpty;
}

class AuthController extends AsyncNotifier<AuthUser?> {
  AuthTokens? _tokens;
  AuthTokens? get tokens => _tokens;
  late final AuthRepository _repo = AuthRepository();
  late final SocialAuthService _socialAuth = SocialAuthService();

  static const _prefsAccessToken = 'auth_access_token';
  static const _prefsRefreshToken = 'auth_refresh_token';
  static const _prefsTokenType = 'auth_token_type';

  Future<void> _persistTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAccessToken, tokens.accessToken);
    await prefs.setString(_prefsRefreshToken, tokens.refreshToken);
    await prefs.setString(_prefsTokenType, tokens.tokenType);
  }

  Future<AuthTokens?> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_prefsAccessToken) ?? '';
    final refresh = prefs.getString(_prefsRefreshToken) ?? '';
    final type = prefs.getString(_prefsTokenType) ?? 'Bearer';
    if (access.isNotEmpty && refresh.isNotEmpty) {
      return AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        tokenType: type,
      );
    }
    return null;
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAccessToken);
    await prefs.remove(_prefsRefreshToken);
    await prefs.remove(_prefsTokenType);
  }

  String _resolveUserId({String fallback = 'self'}) {
    return PostHogService.extractUserIdFromAccessToken(_tokens?.accessToken) ??
        fallback;
  }

  void _trackAuthenticatedUser(
    AuthUser user, {
    required String authMethod,
    required String source,
  }) {
    final distinctId = PostHogService.resolveDistinctId(
      userId: user.id,
      email: user.email,
      accessToken: _tokens?.accessToken,
    );
    if (distinctId.isEmpty) return;

    unawaited(
      PostHogService.identifyUser(
        distinctId: distinctId,
        email: user.email,
        displayName: user.displayName,
        username: user.username,
        authMethod: authMethod,
        source: source,
      ),
    );

    unawaited(
      PostHogService.capture(
        'user_authenticated',
        properties: {
          'auth_method': authMethod,
          'auth_source': source,
          'distinct_id': distinctId,
        },
      ),
    );
  }

  void _resetTrackedUser({required String source}) {
    unawaited(() async {
      await PostHogService.capture(
        'user_logged_out',
        properties: {'source': source},
      );
      await PostHogService.reset();
    }());
  }

  void _syncPushNotificationsForUser(AuthUser? user) {
    if (user == null) return;
    unawaited(ref.read(pushNotificationServiceProvider).syncUser(user));
  }

  @override
  Future<AuthUser?> build() async {
    _setupTokenRefresher();
    final restored = await _loadTokens();
    if (restored == null || !restored.isValid) return null;

    _tokens = restored;
    ApiClient.I.setAuthTokens(
      accessToken: restored.accessToken,
      refreshToken: restored.refreshToken,
      tokenType: restored.tokenType,
    );

    // Refresh tokens on launch so we don't drop the session due to an expired access token.
    try {
      final refreshedMap = await _repo.refreshToken(
        refreshToken: restored.refreshToken,
      );
      final refreshedTokens = AuthTokens(
        accessToken: refreshedMap['access_token'] ?? restored.accessToken,
        refreshToken: refreshedMap['refresh_token'] ?? restored.refreshToken,
        tokenType: refreshedMap['token_type'] ?? restored.tokenType,
      );
      _tokens = refreshedTokens;
      ApiClient.I.setAuthTokens(
        accessToken: refreshedTokens.accessToken,
        refreshToken: refreshedTokens.refreshToken,
        tokenType: refreshedTokens.tokenType,
      );
      await _persistTokens(refreshedTokens);
    } catch (e) {
      // Only clear tokens when the refresh token is definitively rejected by the server.
      // Network errors (timeout, no connection) should preserve tokens so the
      // 401 interceptor can retry later when connectivity is restored.
      final isAuthFailure =
          e is DioException &&
          e.response != null &&
          (e.response!.statusCode == 401 ||
              e.response!.statusCode == 403 ||
              e.response!.statusCode == 422);
      if (isAuthFailure) {
        _tokens = null;
        ApiClient.I.clearAuthTokens();
        await _clearTokens();
        _resetTrackedUser(source: 'startup_refresh_rejected');
        return null;
      }
      // Transient error – keep existing tokens (already set above in ApiClient).
    }

    final email = await EmailStorageService.getLastEmail() ?? '';
    final user = AuthUser(
      id: _resolveUserId(),
      email: email,
      emailVerificationRequired: false,
    );
    _trackAuthenticatedUser(
      user,
      authMethod: 'token_refresh',
      source: 'startup_restore',
    );
    _syncPushNotificationsForUser(user);
    return user;
  }

  void _setupTokenRefresher() {
    ApiClient.I.setTokenRefresher((refreshToken) async {
      try {
        final map = await _repo.refreshToken(refreshToken: refreshToken);
        final newTokens = AuthTokens(
          accessToken: map['access_token'] ?? '',
          refreshToken: map['refresh_token'] ?? refreshToken,
          tokenType: map['token_type'] ?? 'bearer',
        );
        _tokens = newTokens;
        ApiClient.I.setAuthTokens(
          accessToken: newTokens.accessToken,
          refreshToken: newTokens.refreshToken,
          tokenType: newTokens.tokenType,
        );
        await _persistTokens(newTokens);
        // Keep the current user; just refreshed tokens.
        return true;
      } catch (e) {
        // Only clear tokens when the server definitively rejects the refresh token.
        // Network errors should preserve tokens for future retry.
        final isAuthFailure =
            e is DioException &&
            e.response != null &&
            (e.response!.statusCode == 401 ||
                e.response!.statusCode == 403 ||
                e.response!.statusCode == 422);
        if (isAuthFailure) {
          _tokens = null;
          ApiClient.I.clearAuthTokens();
          await _clearTokens();
          state = const AsyncValue.data(null);
          _resetTrackedUser(source: 'token_refresh_rejected');
        }
        return false;
      }
    });
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
    String? username,
  }) async {
    state = const AsyncValue.loading();
    try {
      final registeredUser = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        username: username,
      );
      // Auto-login after registration to obtain auth tokens.
      final tokensMap = await _repo.login(email: email, password: password);
      _tokens = AuthTokens(
        accessToken: tokensMap['access_token']!,
        refreshToken: tokensMap['refresh_token']!,
        tokenType: tokensMap['token_type']!,
      );
      ApiClient.I.setAuthTokens(
        accessToken: _tokens!.accessToken,
        refreshToken: _tokens!.refreshToken,
        tokenType: _tokens!.tokenType,
      );
      await _persistTokens(_tokens!);
      final user = AuthUser(
        id: _resolveUserId(
          fallback: registeredUser.id.isNotEmpty ? registeredUser.id : 'self',
        ),
        email: email,
        emailVerificationRequired: registeredUser.emailVerificationRequired,
        displayName: registeredUser.displayName ?? displayName,
        username: registeredUser.username ?? username,
      );
      state = AsyncValue.data(user);
      _trackAuthenticatedUser(user, authMethod: 'password', source: 'register');
      _syncPushNotificationsForUser(user);
    } on DioException catch (e, st) {
      final apiError = ErrorFormatter.fromDio(e);
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final tokensMap = await _repo.login(email: email, password: password);
      _tokens = AuthTokens(
        accessToken: tokensMap['access_token']!,
        refreshToken: tokensMap['refresh_token']!,
        tokenType: tokensMap['token_type']!,
      );
      ApiClient.I.setAuthTokens(
        accessToken: _tokens!.accessToken,
        refreshToken: _tokens!.refreshToken,
        tokenType: _tokens!.tokenType,
      );
      await _persistTokens(_tokens!);
      final user = AuthUser(
        id: _resolveUserId(),
        email: email,
        emailVerificationRequired: false,
      );
      state = AsyncValue.data(user);
      _trackAuthenticatedUser(user, authMethod: 'password', source: 'login');
      _syncPushNotificationsForUser(user);
    } on DioException catch (e, st) {
      final apiError = ErrorFormatter.fromDio(e);
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      debugPrint('[AuthController] signInWithGoogle start');
      final idToken = await _socialAuth.signInWithGoogle().timeout(
        const Duration(seconds: 75),
        onTimeout: () => throw Exception(
          'Google sign-in timed out before returning to the app.',
        ),
      );
      debugPrint(
        '[AuthController] received Firebase ID token (${idToken.length} chars)',
      );
      await _handleFirebaseAuth(idToken, authMethod: 'google');
      debugPrint('[AuthController] backend /auth/firebase success');
    } on DioException catch (e, st) {
      final apiError = ErrorFormatter.fromDio(e);
      debugPrint(
        '[AuthController] backend /auth/firebase failed: ${apiError.message}',
      );
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[AuthController] Google sign-in failed before backend: $msg');
      state = AsyncValue.error(msg, st);
    }
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      debugPrint('[AuthController] signInWithApple start');
      final idToken = await _socialAuth.signInWithApple().timeout(
        const Duration(seconds: 75),
        onTimeout: () => throw Exception(
          'Apple sign-in timed out before returning to the app.',
        ),
      );
      debugPrint(
        '[AuthController] received Firebase ID token (${idToken.length} chars)',
      );
      await _handleFirebaseAuth(idToken, authMethod: 'apple');
      debugPrint('[AuthController] backend /auth/firebase success');
    } on DioException catch (e, st) {
      final apiError = ErrorFormatter.fromDio(e);
      debugPrint(
        '[AuthController] backend /auth/firebase failed: ${apiError.message}',
      );
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[AuthController] Apple sign-in failed before backend: $msg');
      state = AsyncValue.error(msg, st);
    }
  }

  Future<void> _handleFirebaseAuth(
    String idToken, {
    required String authMethod,
  }) async {
    final tokensMap = await _repo.firebaseAuth(idToken: idToken);
    _tokens = AuthTokens(
      accessToken: tokensMap['access_token']!,
      refreshToken: tokensMap['refresh_token']!,
      tokenType: tokensMap['token_type']!,
    );
    ApiClient.I.setAuthTokens(
      accessToken: _tokens!.accessToken,
      refreshToken: _tokens!.refreshToken,
      tokenType: _tokens!.tokenType,
    );
    await _persistTokens(_tokens!);
    final tokenEmail =
        PostHogService.extractEmailFromAccessToken(_tokens?.accessToken) ?? '';
    final user = AuthUser(
      id: _resolveUserId(),
      email: tokenEmail,
      emailVerificationRequired: false,
    );
    state = AsyncValue.data(user);
    _trackAuthenticatedUser(
      user,
      authMethod: authMethod,
      source: 'social_login',
    );
    _syncPushNotificationsForUser(user);
  }

  Future<void> logout() async {
    final refresh = _tokens?.refreshToken;
    try {
      await ref
          .read(pushNotificationServiceProvider)
          .unregisterCurrentDeviceToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _repo.logout(refreshToken: refresh);
      }
    } on DioException catch (e, st) {
      // We still proceed to clear local auth, but expose error for listeners
      final apiError = ErrorFormatter.fromDio(e);
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    } finally {
      _tokens = null;
      ApiClient.I.clearAuthTokens();
      await _clearTokens();
      // Clear the stored email for privacy
      await EmailStorageService.clearLastEmail();
      // Clear the authenticated user
      state = const AsyncValue.data(null);
      _resetTrackedUser(source: 'logout');
    }
  }

  /// Request a password reset code to be sent to the given email.
  /// Returns the success message from the server (generic to prevent enumeration).
  Future<String> sendResetCode({required String email}) async {
    try {
      return await _repo.requestPasswordReset(email: email);
    } on DioException catch (e) {
      final apiError = ErrorFormatter.fromDio(e);
      throw apiError;
    }
  }

  /// Perform password reset using the 6-digit token.
  /// Returns the success message from the server.
  Future<String> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      return await _repo.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
    } on DioException catch (e) {
      final apiError = ErrorFormatter.fromDio(e);
      throw apiError;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);
