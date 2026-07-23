import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/presentation/widgets/stock_count_card.dart';

StockCount _stockCount({String status = 'OPEN', double totalVarQty = 0}) {
  return StockCount(
    companyId: 'BAS',
    branchId: 'BAS1',
    stockcntId: 'SC0089',
    cntType: 'CNT',
    status: status,
    stockcntDate: '2020-08-02',
    whseCode: 'BBPOS',
    totalItems: 3,
    totalCountQty: 45,
    totalVarQty: totalVarQty,
    dateUpdated: '2020-08-02T10:00:00',
    lines: const [],
  );
}

void main() {
  testWidgets('shows the stock count id, status, warehouse, and item count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StockCountCard(stockCount: _stockCount(), onTap: () {}))),
    );

    expect(find.text('SC0089'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.textContaining('BBPOS'), findsOneWidget);
    expect(find.textContaining('3 items'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StockCountCard(stockCount: _stockCount(), onTap: () => tapped = true))),
    );

    await tester.tap(find.byType(StockCountCard));
    expect(tapped, isTrue);
  });

  testWidgets('shows the variance figure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StockCountCard(stockCount: _stockCount(totalVarQty: -2), onTap: () {}))),
    );

    expect(find.text('-2.0'), findsOneWidget);
  });
}
