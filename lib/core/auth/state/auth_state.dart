import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../repository/auth_repository.dart';
import '../../network/error_formatter.dart';

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
      state = AsyncValue.data(AuthUser(id: 'self', email: email, emailVerificationRequired: false));
    } on DioException catch (e, st) {
      final apiError = ErrorFormatter.fromDio(e);
      state = AsyncValue.error(apiError.message, st);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  void logout() {
    _tokens = null;
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
