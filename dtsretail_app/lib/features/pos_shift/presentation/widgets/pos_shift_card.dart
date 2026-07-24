import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/pos_shift.dart';
import 'pos_shift_status_chip.dart';

class PosShiftCard extends StatelessWidget {
  const PosShiftCard({super.key, required this.shift, required this.onTap});

  final PosShift shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final variance = shift.amountVariance;
    final varianceColor = variance == 0 ? AppColors.neutral : AppColors.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${shift.termName ?? shift.terminalId} · #${shift.shiftNo}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PosShiftStatusChip(isOpen: shift.isOpen),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(shift.shiftDateStr, style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
                ],
              ),
            ),
            Text(
              variance.toStringAsFixed(2),
              style: TextStyle(fontWeight: FontWeight.w700, color: varianceColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
