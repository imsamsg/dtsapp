import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

Color posShiftStatusColor(bool isOpen) => isOpen ? AppColors.primary : AppColors.neutral;

class PosShiftStatusChip extends StatelessWidget {
  const PosShiftStatusChip({super.key, required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = posShiftStatusColor(isOpen);
    final label = isOpen ? 'OPEN' : 'CLOSED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
