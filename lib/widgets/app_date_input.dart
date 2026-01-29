import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:antroph_mobile/core/theme/theme_provider.dart';

/// A reusable date input styled like [AppInput] that opens a Cupertino date picker.
///
/// - Shows a hint when no value is picked
/// - Taps open a bottom sheet with a CupertinoDatePicker
/// - Dark themed to match the app
class AppDateInput extends StatefulWidget {
  const AppDateInput({
    super.key,
    required this.hint,
    required this.onChanged,
    this.value,
    this.icon = Icons.cake_outlined,
    this.firstDate,
    this.lastDate,
  });

  final String hint;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final IconData icon;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<AppDateInput> createState() => _AppDateInputState();
}

class _AppDateInputState extends State<AppDateInput> {
  DateTime? _temp;

  String _format(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _openPicker() async {
    final now = DateTime.now();
    final initial = widget.value ?? DateTime(now.year - 18, now.month, now.day);
    final first = widget.firstDate ?? DateTime(1900);
    final last = widget.lastDate ?? now;
    _temp = initial;
    final isDark = context.isDarkMode;
    final borderColor = context.dividerColor;
    final sheetColor = context.surfaceColor;

    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: sheetColor,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      onPressed: () {
                        if (_temp != null) widget.onChanged(_temp!);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    minimumDate: first,
                    maximumDate: last,
                    initialDateTime: initial,
                    onDateTimeChanged: (d) => _temp = d,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.value != null ? _format(widget.value!) : widget.hint;
    final isHint = widget.value == null;
    final textColor = context.primaryTextColor;
    final hintColor = context.tertiaryTextColor;
    final iconColor = context.secondaryTextColor;

    return InkWell(
      onTap: _openPicker,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: context.inputBackground,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: isHint ? hintColor : textColor, fontSize: 15),
              ),
            ),
            Icon(Icons.calendar_today_outlined, color: iconColor, size: 20),
          ],
        ),
      ),
    );
  }
}
