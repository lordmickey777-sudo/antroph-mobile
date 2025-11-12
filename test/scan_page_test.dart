import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antroph_mobile/features/profile/presentation/scan_page.dart';

void main() {
  testWidgets('ScanPage builds with placeholder when scanner disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanPage(enableScanner: false)));

    // Expect the placeholder text instead of camera preview
    expect(find.text('Scanner disabled in test'), findsOneWidget);
    expect(find.text('Scan QR Code'), findsOneWidget);
  });
}
