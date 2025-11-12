import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: const Color(0xFF1A1D1F),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24, width: 0.5)),
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
                  data: const CupertinoThemeData(brightness: Brightness.dark),
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

    return InkWell(
      onTap: _openPicker,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2223),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: Colors.white70, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: isHint ? Colors.white38 : Colors.white, fontSize: 15),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}
