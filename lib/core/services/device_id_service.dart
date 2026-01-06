import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for obtaining a stable device identifier.
///
/// Uses platform-specific device identifiers where available,
/// with fallback to a persisted UUID.
class DeviceIdService {
  static const _prefsFallbackDeviceId = 'device_id_fallback';
  static String? _cachedDeviceId;

  /// Get the device ID. Returns a platform-specific identifier when available.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final deviceInfo = DeviceInfoPlugin();
    String? deviceId;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // androidId is unique per app signing key and user
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // identifierForVendor is unique per vendor (app developer)
        deviceId = iosInfo.identifierForVendor;
      }
    } catch (_) {
      // Fall through to fallback
    }

    // Use fallback if platform ID unavailable
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = await _getFallbackDeviceId();
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Get or generate a fallback device ID using UUID.
  static Future<String> _getFallbackDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var fallbackId = prefs.getString(_prefsFallbackDeviceId);

    if (fallbackId == null || fallbackId.isEmpty) {
      fallbackId = _generateUuid();
      await prefs.setString(_prefsFallbackDeviceId, fallbackId);
    }

    return fallbackId;
  }

  /// Simple UUID v4 generator without external dependencies.
  static String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();

    for (var i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) {
        buffer.write('-');
      }
      final digit = ((random >> (i % 16)) ^ (i * 31)) & 0xF;
      buffer.write(digit.toRadixString(16));
    }

    return buffer.toString();
  }

  /// Clear cached device ID (useful for testing).
  static void clearCache() {
    _cachedDeviceId = null;
  }
}
