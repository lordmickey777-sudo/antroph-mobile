import 'package:flutter/material.dart';

import 'typography_text.dart';

/// Reusable dropdown styled consistently with the app's inputs.
class AppDropdown extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select',
    this.validator,
    this.enabled = true,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;
  final String hint;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypographyText(
          label,
          color: Colors.white70,
          variant: TypographyVariant.body2,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2223),
            borderRadius: BorderRadius.circular(40),
          ),
          child: DropdownButtonFormField<String>(
            value: options.containsKey(value) ? value : null,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
            ),
            dropdownColor: const Color(0xFF1F2223),
            borderRadius: BorderRadius.circular(12),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            iconEnabledColor: Colors.white70,
            iconSize: 22,
            items: [
              for (final entry in options.entries)
                DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
            onChanged: enabled ? onChanged : null,
            validator: validator,
          ),
        ),
      ],
    );
  }
}
