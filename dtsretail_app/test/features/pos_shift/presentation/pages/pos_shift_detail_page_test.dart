import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pay_summary.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/pages/pos_shift_detail_page.dart';

/// Grow the test surface so all content in the ListView is rendered.
/// ListView only lays out children within the viewport (plus a small cache extent),
/// so items past that are never built and find() doesn't see them.
Future<void> _growSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

PosShift _shift({
  bool lineDelYN = false,
  bool voidSaleYN = false,
  List<PaySummary> paymentSummary = const [],
  int totalBills = 20,
  double totalCost = 300,
}) {
  return PosShift(
    companyId: 'BAS',
    branchId: 'BAS1',
    terminalId: 'T01',
    termName: 'Main Counter',
    shiftNo: '202507003',
    shiftDateStr: '2026-07-20',
    logOnDateTimeStr: '2026-07-20 08:00:00',
    logOffDateTimeStr: '2026-07-20 17:00:00',
    posOperatorId: 'OP01',
    amountCash: 500,
    amountNonCash: 250,
    amountVariance: -2.5,
    openAmount: 100,
    cashInDraw: 600,
    cashCollected: 500,
    amountDrawn: 597.5,
    targetAmount: 500,
    totalGstAmount: 42,
    totalBills: totalBills,
    totalQty: 55,
    totalCost: totalCost,
    lineDelYN: lineDelYN,
    totalLineDel: 2,
    voidSaleYN: voidSaleYN,
    totalVoidSale: 3,
    paymentSummary: paymentSummary,
  );
}

void main() {
  testWidgets('renders header, KPI strip, and all InfoSectionCard sections', (tester) async {
    await _growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift())));

    expect(find.text('Main Counter'), findsOneWidget);
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('Payment Summary'), findsOneWidget);
    expect(find.text('Sales Summary'), findsOneWidget);
    expect(find.text('Drawer Summary'), findsOneWidget);
    expect(find.text('Transaction Metrics'), findsOneWidget);
    expect(find.text('Total Sales'), findsOneWidget);
  });

  testWidgets('renders payment summary rows dynamically, not from a hardcoded mode list', (tester) async {
    await _growSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PosShiftDetailPage(
          shift: _shift(
            paymentSummary: const [
              PaySummary(payMode: 'STARDUST_CREDIT', totalAmount: 120),
              PaySummary(payMode: 'MOONBEAM_WALLET', totalAmount: 30.5),
            ],
          ),
        ),
      ),
    );

    expect(find.text('STARDUST_CREDIT'), findsOneWidget);
    expect(find.text('120.00'), findsOneWidget);
    expect(find.text('MOONBEAM_WALLET'), findsOneWidget);
    expect(find.text('30.50'), findsOneWidget);
    // 150.50 appears three times: the KPI strip's "Total Sales" cell,
    // the Payment Summary card's appended "Total" row, and the Sales Summary
    // card's "Total" row all derive from the same PosShift.totalSales getter.
    expect(find.text('150.50'), findsNWidgets(3));
  });

  testWidgets('shows Line Deletions and Void Sales only when their flags are true', (tester) async {
    await _growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift())));
    expect(find.text('Line Deletions'), findsNothing);
    expect(find.text('Void Sales'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift(lineDelYN: true, voidSaleYN: true))));
    expect(find.text('Line Deletions'), findsOneWidget);
    expect(find.text('Void Sales'), findsOneWidget);
  });

  testWidgets('shows a dash for average bill value when there are no bills', (tester) async {
    await _growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: PosShiftDetailPage(shift: _shift(totalBills: 0))));
    expect(find.text('–'), findsOneWidget);
  });
}
