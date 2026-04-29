import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../auth/models/user.dart';
import '../logging/logger.dart';
import '../network/api_client.dart';
import '../network/error_formatter.dart';
import '../services/device_id_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!_supportsPushNotifications) return;

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final title = message.notification?.title ?? '';
  final body = message.notification?.body ?? '';
  debugPrint(
    '[Push] Background message id=${message.messageId} title="$title" body="$body" data=${message.data}',
  );
}

bool get _supportsPushNotifications {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, Dio? dio})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _dio = dio ?? ApiClient.I.dio;

  static const _prefsRegisteredToken = 'push_registered_fcm_token';
  static const _prefsRegisteredUserId = 'push_registered_user_id';

  static bool _backgroundHandlerRegistered = false;

  final FirebaseMessaging _messaging;
  final Dio _dio;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  bool _initialized = false;
  String? _activeUserId;

  static void registerBackgroundHandler() {
    if (!_supportsPushNotifications || _backgroundHandlerRegistered) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsPushNotifications) return;
    _initialized = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      unawaited(_registerToken(candidateToken: newToken, force: true));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> syncUser(AuthUser? user) async {
    if (!_supportsPushNotifications) return;

    _activeUserId = user?.id.trim();
    if (_activeUserId == null || _activeUserId!.isEmpty) {
      return;
    }

    await _registerToken();
  }

  Future<void> unregisterCurrentDeviceToken() async {
    if (!_supportsPushNotifications) return;

    try {
      await _dio.delete('/users/me/fcm-token');
      Log.i.i('[Push] Unregistered FCM token for current user.');
    } on DioException catch (error) {
      final apiError = ErrorFormatter.fromDio(error);
      Log.i.w('[Push] Failed to unregister FCM token: ${apiError.message}');
    } catch (error, stackTrace) {
      Log.i.w('[Push] Failed to unregister FCM token: $error');
      Log.i.d(stackTrace.toString());
    } finally {
      _activeUserId = null;
      await _clearRegistrationCache();
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
  }

  Future<void> _registerToken({
    String? candidateToken,
    bool force = false,
  }) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorized) {
        Log.i.i(
          '[Push] Notification permission not granted; skipping FCM token registration.',
        );
        return;
      }

      final token = (candidateToken ?? await _messaging.getToken())?.trim();
      if (token == null || token.isEmpty) {
        Log.i.w('[Push] Firebase Messaging returned an empty device token.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_prefsRegisteredToken) ?? '';
      final cachedUserId = prefs.getString(_prefsRegisteredUserId) ?? '';

      if (!force && token == cachedToken && userId == cachedUserId) {
        return;
      }

      final deviceId = await DeviceIdService.getDeviceId();
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

      await _dio.post(
        '/users/me/fcm-token',
        data: {'fcm_token': token, 'device_id': deviceId, 'platform': platform},
      );
      await prefs.setString(_prefsRegisteredToken, token);
      await prefs.setString(_prefsRegisteredUserId, userId);
      Log.i.i('[Push] Registered FCM token for user $userId.');
    } on DioException catch (error) {
      final apiError = ErrorFormatter.fromDio(error);
      Log.i.w('[Push] Failed to register FCM token: ${apiError.message}');
    } catch (error, stackTrace) {
      Log.i.w('[Push] Failed to register FCM token: $error');
      Log.i.d(stackTrace.toString());
    }
  }

  Future<void> _clearRegistrationCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRegisteredToken);
    await prefs.remove(_prefsRegisteredUserId);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    Log.i.i(
      '[Push] Foreground notification id=${message.messageId} title="$title" body="$body" data=${message.data}',
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final storyId = message.data['story_id']?.trim();
    Log.i.i(
      '[Push] Notification opened id=${message.messageId} story_id=${storyId ?? ''} data=${message.data}',
    );
  }
}
