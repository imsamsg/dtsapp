import '../models/pay_summary_dto.dart';
import '../models/pos_shift_dto.dart';
import '../../domain/entities/pay_summary.dart';
import '../../domain/entities/pos_shift.dart';

extension PaySummaryDtoMapper on PaySummaryDto {
  PaySummary toDomain() {
    return PaySummary(payMode: payMode, totalAmount: totalAmount ?? 0);
  }
}

extension PosShiftDtoMapper on PosShiftDto {
  PosShift toDomain() {
    return PosShift(
      companyId: companyId,
      branchId: branchId,
      terminalId: terminalId,
      termName: termName,
      shiftNo: shiftNo,
      shiftDateStr: shiftDateStr ?? '',
      logOnDateTimeStr: logOnDateTimeStr,
      logOffDateTimeStr: logOffDateTimeStr,
      posOperatorId: posOperatorId,
      amountCash: amountCash ?? 0,
      amountNonCash: amountNonCash ?? 0,
      amountVariance: amountVariance ?? 0,
      openAmount: openAmount ?? 0,
      cashInDraw: cashInDraw ?? 0,
      cashCollected: cashCollected ?? 0,
      amountDrawn: amountDrawn ?? 0,
      targetAmount: targetAmount ?? 0,
      totalGstAmount: totalGstAmount ?? 0,
      totalBills: totalBills ?? 0,
      totalQty: totalQty ?? 0,
      totalCost: totalCost ?? 0,
      lineDelYN: lineDelYN ?? false,
      totalLineDel: totalLineDel ?? 0,
      voidSaleYN: voidSaleYN ?? false,
      totalVoidSale: totalVoidSale ?? 0,
      paymentSummary: (lstPaySummDto ?? const []).map((p) => p.toDomain()).toList(),
    );
  }
}
