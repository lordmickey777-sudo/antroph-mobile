import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../repository/auth_repository.dart';
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

  @override
  Future<AuthUser?> build() async {
    // No persisted auth yet.
    // Wire token refresher so the HTTP layer can refresh on 401.
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
        // Keep the current user; just refreshed tokens.
        return true;
      } catch (_) {
        // On refresh failure ensure tokens are cleared and auth state reset.
        _tokens = null;
        ApiClient.I.clearAuthTokens();
        // Expose unauth state (do not emit error from build).
        state = const AsyncValue.data(null);
        return false;
      }
    });
    return null;
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
