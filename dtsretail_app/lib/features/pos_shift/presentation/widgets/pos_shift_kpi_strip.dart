import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class PosShiftKpiStrip extends StatelessWidget {
  const PosShiftKpiStrip({
    super.key,
    required this.totalSales,
    required this.cash,
    required this.nonCash,
    required this.variance,
  });

  final double totalSales;
  final double cash;
  final double nonCash;
  final double variance;

  @override
  Widget build(BuildContext context) {
    final varianceColor = variance == 0 ? AppColors.neutral : AppColors.danger;
    return Row(
      children: [
        Expanded(child: _KpiCell(label: 'Total Sales', value: totalSales.toStringAsFixed(2))),
        Expanded(child: _KpiCell(label: 'Cash', value: cash.toStringAsFixed(2))),
        Expanded(child: _KpiCell(label: 'Non-Cash', value: nonCash.toStringAsFixed(2))),
        Expanded(child: _KpiCell(label: 'Variance', value: variance.toStringAsFixed(2), valueColor: varianceColor)),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.neutral)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}
