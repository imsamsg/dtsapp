import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/app/theme/app_theme.dart';
import 'package:dtsretail_app/features/stock_count/presentation/widgets/stock_count_status_chip.dart';

void main() {
  testWidgets('shows the OPEN label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'OPEN')));
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('shows the APPROVED label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'APPROVED')));
    expect(find.text('APPROVED'), findsOneWidget);
  });

  testWidgets('shows the POSTED label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'POSTED')));
    expect(find.text('POSTED'), findsOneWidget);
  });

  testWidgets('falls back gracefully for an unrecognized status', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'UNKNOWN')));
    expect(find.text('UNKNOWN'), findsOneWidget);
  });

  test('stockCountStatusColor maps the three real lifecycle values', () {
    expect(stockCountStatusColor('OPEN'), AppColors.primary);
    expect(stockCountStatusColor('APPROVED'), AppColors.accent);
    expect(stockCountStatusColor('POSTED'), AppColors.neutral);
    expect(stockCountStatusColor('UNKNOWN'), AppColors.neutral);
  });
}
