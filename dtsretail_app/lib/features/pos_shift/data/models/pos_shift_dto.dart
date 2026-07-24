import 'package:json_annotation/json_annotation.dart';
import 'pay_summary_dto.dart';

part 'pos_shift_dto.g.dart';

@JsonSerializable(createToJson: false)
class PosShiftDto {
  PosShiftDto({
    required this.companyId,
    required this.branchId,
    required this.terminalId,
    this.termName,
    required this.shiftNo,
    this.shiftDateStr,
    this.logOnDateTimeStr,
    this.logOffDateTimeStr,
    this.posOperatorId,
    this.amountCash,
    this.amountNonCash,
    this.amountVariance,
    this.openAmount,
    this.cashInDraw,
    this.cashCollected,
    this.amountDrawn,
    this.targetAmount,
    this.totalGstAmount,
    this.totalBills,
    this.totalQty,
    this.totalCost,
    this.lineDelYN,
    this.totalLineDel,
    this.voidSaleYN,
    this.totalVoidSale,
    this.lstPaySummDto,
  });

  final String companyId;
  final String branchId;
  final String terminalId;
  final String? termName;
  final String shiftNo;
  final String? shiftDateStr;
  final String? logOnDateTimeStr;
  final String? logOffDateTimeStr;
  final String? posOperatorId;
  final double? amountCash;
  final double? amountNonCash;
  final double? amountVariance;
  final double? openAmount;
  final double? cashInDraw;
  final double? cashCollected;
  final double? amountDrawn;
  final double? targetAmount;
  final double? totalGstAmount;
  final int? totalBills;
  final double? totalQty;
  final double? totalCost;
  final bool? lineDelYN;
  final int? totalLineDel;
  final bool? voidSaleYN;
  final int? totalVoidSale;
  final List<PaySummaryDto>? lstPaySummDto;

  factory PosShiftDto.fromJson(Map<String, dynamic> json) => _$PosShiftDtoFromJson(json);
}
