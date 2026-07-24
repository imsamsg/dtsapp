import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/data/mappers/pos_shift_mapper.dart';
import 'package:dtsretail_app/features/pos_shift/data/models/pay_summary_dto.dart';
import 'package:dtsretail_app/features/pos_shift/data/models/pos_shift_dto.dart';

void main() {
  test('maps all fields to the domain entity and computes totalSales/isOpen', () {
    final dto = PosShiftDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      terminalId: 'T01',
      termName: 'Main Counter',
      shiftNo: '202507003',
      shiftDateStr: '2026-07-20',
      logOnDateTimeStr: '2026-07-20 08:00:00',
      logOffDateTimeStr: '2026-07-20 17:00:00',
      posOperatorId: 'OP01',
      amountCash: 500.0,
      amountNonCash: 250.5,
      amountVariance: -2.5,
      openAmount: 100.0,
      cashInDraw: 600.0,
      cashCollected: 500.0,
      amountDrawn: 597.5,
      targetAmount: 500.0,
      totalGstAmount: 42.0,
      totalBills: 20,
      totalQty: 55.0,
      totalCost: 300.0,
      lineDelYN: true,
      totalLineDel: 2,
      voidSaleYN: false,
      totalVoidSale: 0,
      lstPaySummDto: [
        PaySummaryDto(payMode: 'CASH', totalAmount: 500.0),
        PaySummaryDto(payMode: 'GRABPAY', totalAmount: 250.5),
      ],
    );

    final domain = dto.toDomain();

    expect(domain.companyId, 'BAS');
    expect(domain.terminalId, 'T01');
    expect(domain.termName, 'Main Counter');
    expect(domain.shiftNo, '202507003');
    expect(domain.amountCash, 500.0);
    expect(domain.amountVariance, -2.5);
    expect(domain.lineDelYN, isTrue);
    expect(domain.totalLineDel, 2);
    expect(domain.voidSaleYN, isFalse);
    expect(domain.paymentSummary, hasLength(2));
    expect(domain.paymentSummary.first.payMode, 'CASH');
    expect(domain.totalSales, closeTo(750.5, 0.001));
    expect(domain.isOpen, isFalse);
  });

  test('a null logOffDateTimeStr maps to an open shift; missing numerics default to zero', () {
    final dto = PosShiftDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      terminalId: 'T01',
      shiftNo: '202507004',
      lstPaySummDto: const [],
    );

    final domain = dto.toDomain();

    expect(domain.isOpen, isTrue);
    expect(domain.termName, isNull);
    expect(domain.amountCash, 0);
    expect(domain.totalSales, 0);
    expect(domain.paymentSummary, isEmpty);
  });
}
