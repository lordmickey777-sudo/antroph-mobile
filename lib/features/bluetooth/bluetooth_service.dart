import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adapterStateProvider = StreamProvider<BluetoothAdapterState>(
  (ref) => FlutterBluePlus.adapterState,
);

final scanResultsProvider = StreamProvider<List<ScanResult>>(
  (ref) => FlutterBluePlus.scanResults,
);

final isScanningProvider = StreamProvider<bool>(
  (ref) => FlutterBluePlus.isScanning,
);

final bluetoothScannerProvider = Provider<BluetoothScanner>((ref) {
  return BluetoothScanner();
});

class BluetoothScanner {
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}
