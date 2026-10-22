import 'package:flutter/material.dart';

class VerifiedPBadge extends StatelessWidget {
  final bool compact;
  const VerifiedPBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade600, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'P+',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 11 : 13,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.verified_rounded,
            size: compact ? 13 : 16,
            color: Colors.green.shade600,
          ),
        ],
      ),
    );
  }
}
