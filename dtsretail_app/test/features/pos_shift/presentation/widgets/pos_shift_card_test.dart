import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/widgets/pos_shift_card.dart';

PosShift _shift({String? logOffDateTimeStr = '2026-07-20 17:00:00', double amountVariance = 0}) {
  return PosShift(
    companyId: 'BAS',
    branchId: 'BAS1',
    terminalId: 'T01',
    termName: 'Main Counter',
    shiftNo: '202507003',
    shiftDateStr: '2026-07-20',
    logOnDateTimeStr: '2026-07-20 08:00:00',
    logOffDateTimeStr: logOffDateTimeStr,
    posOperatorId: 'OP01',
    amountCash: 500,
    amountNonCash: 250,
    amountVariance: amountVariance,
    openAmount: 100,
    cashInDraw: 600,
    cashCollected: 500,
    amountDrawn: 597.5,
    targetAmount: 500,
    totalGstAmount: 42,
    totalBills: 20,
    totalQty: 55,
    totalCost: 300,
    lineDelYN: false,
    totalLineDel: 0,
    voidSaleYN: false,
    totalVoidSale: 0,
    paymentSummary: const [],
  );
}

void main() {
  testWidgets('shows terminal name, shift number, status, and date', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(), onTap: () {}))));

    expect(find.textContaining('Main Counter'), findsOneWidget);
    expect(find.textContaining('202507003'), findsOneWidget);
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('2026-07-20'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(), onTap: () => tapped = true))));

    await tester.tap(find.byType(PosShiftCard));
    expect(tapped, isTrue);
  });

  testWidgets('shows OPEN for a shift with no logoff time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(logOffDateTimeStr: null), onTap: () {}))),
    );

    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('shows the variance figure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PosShiftCard(shift: _shift(amountVariance: -2.5), onTap: () {}))),
    );

    expect(find.text('-2.50'), findsOneWidget);
  });
}
