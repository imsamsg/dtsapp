import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/app/theme/app_theme.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/widgets/pos_shift_status_chip.dart';

void main() {
  testWidgets('shows OPEN for an open shift', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosShiftStatusChip(isOpen: true)));
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('shows CLOSED for a closed shift', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PosShiftStatusChip(isOpen: false)));
    expect(find.text('CLOSED'), findsOneWidget);
  });

  test('posShiftStatusColor maps open/closed to primary/neutral', () {
    expect(posShiftStatusColor(true), AppColors.primary);
    expect(posShiftStatusColor(false), AppColors.neutral);
  });
}
