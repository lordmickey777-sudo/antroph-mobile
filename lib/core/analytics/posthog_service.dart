import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../env/env.dart';

class PostHogService {
  PostHogService._();

  static final Posthog _posthog = Posthog();
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> setup() async {
    if (_isInitialized) return;

    final apiKey = AppEnv.posthogApiKey.trim();
    if (apiKey.isEmpty) {
      debugPrint('[PostHog] setup skipped: POSTHOG_API_KEY is empty.');
      return;
    }

    final config = PostHogConfig(apiKey);
    config.host = AppEnv.posthogHost.trim().isEmpty
        ? 'https://us.i.posthog.com'
        : AppEnv.posthogHost.trim();
    config.debug = kDebugMode;
    config.captureApplicationLifecycleEvents = true;
    config.sessionReplay = true;
    config.sessionReplayConfig.maskAllTexts = false;
    config.sessionReplayConfig.maskAllImages = false;
    config.sessionReplayConfig.throttleDelay = const Duration(
      milliseconds: 1000,
    );
    config.errorTrackingConfig.captureFlutterErrors = true;
    config.errorTrackingConfig.capturePlatformDispatcherErrors = true;
    config.errorTrackingConfig.captureIsolateErrors = true;
    config.errorTrackingConfig.captureNativeExceptions = true;
    config.errorTrackingConfig.captureSilentFlutterErrors = false;
    config.errorTrackingConfig.inAppIncludes.add('package:antroph_mobile');
    config.errorTrackingConfig.inAppByDefault = true;

    try {
      await _posthog.setup(config);
      _isInitialized = true;
      debugPrint('[PostHog] setup complete.');
    } catch (e) {
      debugPrint('[PostHog] setup failed: $e');
    }
  }

  static Future<void> identifyUser({
    required String distinctId,
    String? email,
    String? displayName,
    String? username,
    String? authMethod,
    String? source,
  }) async {
    if (!_isInitialized) return;

    final id = distinctId.trim();
    if (id.isEmpty) return;

    final userProperties = <String, Object>{
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
      if (authMethod != null && authMethod.trim().isNotEmpty)
        'auth_method': authMethod.trim(),
      if (source != null && source.trim().isNotEmpty)
        'auth_source': source.trim(),
    };

    try {
      final currentDistinctId = await _posthog.getDistinctId();
      if (currentDistinctId.isNotEmpty && currentDistinctId != id) {
        await _posthog.alias(alias: id);
      }
    } catch (_) {
      // Alias linking is best-effort only.
    }

    await _posthog.identify(
      userId: id,
      userProperties: userProperties.isEmpty ? null : userProperties,
    );
  }

  static Future<void> capture(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    if (!_isInitialized) return;
    await _posthog.capture(eventName: eventName, properties: properties);
  }

  static Future<void> reset() async {
    if (!_isInitialized) return;
    await _posthog.reset();
  }

  static Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {
    if (!_isInitialized) return;
    await _posthog.captureException(
      error: error,
      stackTrace: stackTrace,
      properties: properties,
    );
  }

  static Future<void> captureRunZonedGuardedError({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {
    if (!_isInitialized) return;
    await _posthog.captureRunZonedGuardedError(
      error: error,
      stackTrace: stackTrace,
      properties: properties,
    );
  }

  static String resolveDistinctId({
    required String userId,
    required String email,
    String? accessToken,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isNotEmpty && normalizedUserId != 'self') {
      return normalizedUserId;
    }

    final tokenUserId = extractUserIdFromAccessToken(accessToken);
    if (tokenUserId != null && tokenUserId.isNotEmpty) {
      return tokenUserId;
    }

    final normalizedEmail = email.trim();
    if (normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }

    return normalizedUserId == 'self' ? '' : normalizedUserId;
  }

  static String? extractUserIdFromAccessToken(String? accessToken) {
    return _extractClaim(accessToken, const ['sub', 'user_id', 'uid', 'id']);
  }

  static String? extractEmailFromAccessToken(String? accessToken) {
    return _extractClaim(accessToken, const ['email', 'upn']);
  }

  static String? _extractClaim(String? accessToken, List<String> keys) {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) return null;

    final payload = _decodeJwtPayload(token);
    if (payload.isEmpty) return null;

    for (final key in keys) {
      final value = payload[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return const {};

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
      if (json is Map) {
        return json.map((key, value) => MapEntry(key.toString(), value));
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }
}
