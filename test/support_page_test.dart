import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antroph_mobile/features/support/presentation/support_page.dart';

void main() {
  testWidgets('SupportPage shows placeholder when webview disabled', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: SupportPage(enableWebView: false)));

    expect(find.textContaining('Support page (webview disabled in test)'), findsOneWidget);
    expect(find.textContaining('antroph.com'), findsOneWidget);
  });
}
