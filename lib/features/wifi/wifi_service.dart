import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_iot/wifi_iot.dart';

final wifiEnabledProvider = FutureProvider<bool>((ref) async {
  return WiFiForIoTPlugin.isEnabled();
});

final wifiSsidProvider = StreamProvider<String?>((ref) {
  // Poll the SSID periodically as the plugin doesn't expose a stream.
  return Stream.periodic(
    const Duration(seconds: 3),
  ).asyncMap((_) => WiFiForIoTPlugin.getSSID());
});
