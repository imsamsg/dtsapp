// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_shift_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PosShiftDto _$PosShiftDtoFromJson(Map<String, dynamic> json) => PosShiftDto(
  companyId: json['companyId'] as String,
  branchId: json['branchId'] as String,
  terminalId: json['terminalId'] as String,
  termName: json['termName'] as String?,
  shiftNo: json['shiftNo'] as String,
  shiftDateStr: json['shiftDateStr'] as String?,
  logOnDateTimeStr: json['logOnDateTimeStr'] as String?,
  logOffDateTimeStr: json['logOffDateTimeStr'] as String?,
  posOperatorId: json['posOperatorId'] as String?,
  amountCash: (json['amountCash'] as num?)?.toDouble(),
  amountNonCash: (json['amountNonCash'] as num?)?.toDouble(),
  amountVariance: (json['amountVariance'] as num?)?.toDouble(),
  openAmount: (json['openAmount'] as num?)?.toDouble(),
  cashInDraw: (json['cashInDraw'] as num?)?.toDouble(),
  cashCollected: (json['cashCollected'] as num?)?.toDouble(),
  amountDrawn: (json['amountDrawn'] as num?)?.toDouble(),
  targetAmount: (json['targetAmount'] as num?)?.toDouble(),
  totalGstAmount: (json['totalGstAmount'] as num?)?.toDouble(),
  totalBills: (json['totalBills'] as num?)?.toInt(),
  totalQty: (json['totalQty'] as num?)?.toDouble(),
  totalCost: (json['totalCost'] as num?)?.toDouble(),
  lineDelYN: json['lineDelYN'] as bool?,
  totalLineDel: (json['totalLineDel'] as num?)?.toInt(),
  voidSaleYN: json['voidSaleYN'] as bool?,
  totalVoidSale: (json['totalVoidSale'] as num?)?.toInt(),
  lstPaySummDto: (json['lstPaySummDto'] as List<dynamic>?)
      ?.map((e) => PaySummaryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);
