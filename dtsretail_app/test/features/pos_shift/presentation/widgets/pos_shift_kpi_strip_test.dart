import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/widgets/pos_shift_kpi_strip.dart';

void main() {
  testWidgets('renders all four KPI values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PosShiftKpiStrip(totalSales: 750.5, cash: 500, nonCash: 250.5, variance: -2.5)),
      ),
    );

    expect(find.text('Total Sales'), findsOneWidget);
    expect(find.text('750.50'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('500.00'), findsOneWidget);
    expect(find.text('Non-Cash'), findsOneWidget);
    expect(find.text('250.50'), findsOneWidget);
    expect(find.text('Variance'), findsOneWidget);
    expect(find.text('-2.50'), findsOneWidget);
  });
}
