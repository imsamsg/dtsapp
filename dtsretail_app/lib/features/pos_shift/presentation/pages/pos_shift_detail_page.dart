import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/info_section_card.dart';
import '../../domain/entities/pos_shift.dart';
import '../widgets/pos_shift_kpi_strip.dart';
import '../widgets/pos_shift_status_chip.dart';

class PosShiftDetailPage extends StatelessWidget {
  const PosShiftDetailPage({super.key, required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final timeRange = '${shift.logOnDateTimeStr ?? '--'}–${shift.isOpen ? 'Open' : (shift.logOffDateTimeStr ?? '--')}';
    final avgBillValue = shift.totalBills == 0 ? null : shift.totalCost / shift.totalBills;

    final paymentRows = [
      for (final p in shift.paymentSummary) (p.payMode, p.totalAmount.toStringAsFixed(2)),
      ('Total', shift.totalSales.toStringAsFixed(2)),
    ];

    final transactionRows = [
      ('Total Bills', shift.totalBills.toString()),
      ('Total Qty', shift.totalQty.toStringAsFixed(1)),
      ('Avg Bill Value', avgBillValue == null ? '–' : avgBillValue.toStringAsFixed(2)),
      if (shift.lineDelYN) ('Line Deletions', shift.totalLineDel.toString()),
      if (shift.voidSaleYN) ('Void Sales', shift.totalVoidSale.toString()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Shift #${shift.shiftNo}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shift.termName ?? shift.terminalId,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PosShiftStatusChip(isOpen: shift.isOpen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Terminal ${shift.terminalId} · ${shift.posOperatorId ?? '–'} · ${shift.shiftDateStr} · $timeRange',
            style: const TextStyle(color: AppColors.neutral, fontSize: 12),
          ),
          const SizedBox(height: 16),
          PosShiftKpiStrip(
            totalSales: shift.totalSales,
            cash: shift.amountCash,
            nonCash: shift.amountNonCash,
            variance: shift.amountVariance,
          ),
          const SizedBox(height: 20),
          InfoSectionCard(title: 'Payment Summary', rows: paymentRows),
          const SizedBox(height: 12),
          InfoSectionCard(
            title: 'Sales Summary',
            rows: [
              ('Cash', shift.amountCash.toStringAsFixed(2)),
              ('Non-Cash', shift.amountNonCash.toStringAsFixed(2)),
              ('GST', shift.totalGstAmount.toStringAsFixed(2)),
              ('Total', shift.totalSales.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          InfoSectionCard(
            title: 'Drawer Summary',
            rows: [
              ('Opening Amount', shift.openAmount.toStringAsFixed(2)),
              ('Cash In Drawer', shift.cashInDraw.toStringAsFixed(2)),
              ('Cash Collected', shift.cashCollected.toStringAsFixed(2)),
              ('Amount Drawn', shift.amountDrawn.toStringAsFixed(2)),
              ('Target', shift.targetAmount.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          InfoSectionCard(title: 'Transaction Metrics', rows: transactionRows),
        ],
      ),
    );
  }
}
