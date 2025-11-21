import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../repository/auth_repository.dart';
import '../services/email_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../network/error_formatter.dart';
import '../../network/api_client.dart';

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
      return AuthTokens(accessToken: access, refreshToken: refresh, tokenType: type);
    }
    return null;
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAccessToken);
    await prefs.remove(_prefsRefreshToken);
    await prefs.remove(_prefsTokenType);
  }

  @override
  Future<AuthUser?> build() async {
    _setupTokenRefresher();
    // Try to restore tokens from persistent storage
    final restored = await _loadTokens();
    if (restored != null && restored.isValid) {
      _tokens = restored;
      ApiClient.I.setAuthTokens(
        accessToken: restored.accessToken,
        refreshToken: restored.refreshToken,
        tokenType: restored.tokenType,
      );
      // Optionally, fetch user info here if needed
      // For now, just keep user as logged in
      // You may want to validate token with backend here
      // (e.g., fetch profile, handle 401 to auto-logout if expired)
      // For now, return a dummy AuthUser (customize as needed)
      return AuthUser(id: 'self', email: '', emailVerificationRequired: false);
    }
    return null;
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
      } catch (_) {
        // On refresh failure ensure tokens are cleared and auth state reset.
        _tokens = null;
        ApiClient.I.clearAuthTokens();
        await _clearTokens();
        // Expose unauth state (do not emit error from build).
        state = const AsyncValue.data(null);
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
      final user = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        username: username,
      );
      state = AsyncValue.data(user);
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
      state = AsyncValue.data(AuthUser(id: 'self', email: email, emailVerificationRequired: false));
    } on DioException catch (e, st) {
      final apiError = ErrorFormatter.fromDio(e);
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<void> logout() async {
    final refresh = _tokens?.refreshToken;
    try {
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
      EmailStorageService.clearLastEmail();
      // Clear the authenticated user
      state = const AsyncValue.data(null);
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
      return await _repo.resetPassword(email: email, token: token, newPassword: newPassword);
    } on DioException catch (e) {
      final apiError = ErrorFormatter.fromDio(e);
      throw apiError;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
