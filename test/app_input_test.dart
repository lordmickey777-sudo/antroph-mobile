import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('obscured input disables smart text composition', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AppInput(
            controller: controller,
            hint: 'Password',
            obscure: true,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));

    expect(field.keyboardType, TextInputType.visiblePassword);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
    expect(field.textCapitalization, TextCapitalization.none);
  });

  testWidgets('obscured input can delete text to empty', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AppInput(
            controller: controller,
            hint: 'Password',
            obscure: true,
          ),
        ),
      ),
    );

    final field = find.byType(TextFormField);
    await tester.tap(field);
    await tester.enterText(field, 'Abc12345');
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.text, isEmpty);
  });
}
