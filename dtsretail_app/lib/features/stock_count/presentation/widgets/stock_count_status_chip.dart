import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// The real stock-count lifecycle is OPEN -> APPROVED -> POSTED (confirmed
/// against StockCountServiceImpl.java) — no "Closed" state; that belongs to
/// the separate Stock Pick module. Any other value falls back to neutral
/// rather than crashing, since `status` is a raw backend string, not an enum.
Color stockCountStatusColor(String status) {
  switch (status) {
    case 'OPEN':
      return AppColors.primary;
    case 'APPROVED':
      return AppColors.accent;
    case 'POSTED':
      return AppColors.neutral;
    default:
      return AppColors.neutral;
  }
}

class StockCountStatusChip extends StatelessWidget {
  const StockCountStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = stockCountStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
