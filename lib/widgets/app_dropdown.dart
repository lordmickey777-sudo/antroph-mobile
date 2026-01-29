import 'package:flutter/material.dart';

import 'package:antroph_mobile/core/theme/theme_provider.dart';
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
    final textColor = context.primaryTextColor;
    final hintColor = context.tertiaryTextColor;
    final labelColor = context.secondaryTextColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypographyText(
          label,
          color: labelColor,
          variant: TypographyVariant.body2,
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: context.inputBackground,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Center(
            child: DropdownButtonFormField<String>(
              value: options.containsKey(value) ? value : null,
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hint,
                hintStyle: TextStyle(color: hintColor, fontSize: 15),
              ),
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(color: textColor, fontSize: 15),
              iconEnabledColor: labelColor,
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
        ),
      ],
    );
  }
}
