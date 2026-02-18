import 'package:flutter/material.dart';

/// Color-coded pill showing moderation status.
class ModerationStatusBadge extends StatelessWidget {
  const ModerationStatusBadge({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static (String, Color) _resolve(String status) {
    switch (status) {
      case 'pending':
        return ('Pending', Colors.amber.shade700);
      case 'pending_update':
        return ('Pending Update', Colors.orange);
      case 'approved':
        return ('Approved', Colors.green);
      case 'rejected':
        return ('Rejected', Colors.red);
      case 'published':
        return ('Published', Colors.blue);
      default:
        return (status, Colors.grey);
    }
  }
}
