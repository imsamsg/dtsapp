// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_count_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockCountDto _$StockCountDtoFromJson(Map<String, dynamic> json) =>
    StockCountDto(
      companyId: json['companyId'] as String,
      branchId: json['branchId'] as String,
      stockcntId: json['stockcntId'] as String?,
      cntType: json['cntType'] as String,
      status: json['status'] as String,
      stockcntDate: json['stockcntDate'] as String?,
      whseCode: json['whseCode'] as String,
      totalItems: (json['totalItems'] as num?)?.toInt(),
      totalCountQty: (json['totalCountQty'] as num?)?.toDouble(),
      totalVarQty: (json['totalVarQty'] as num?)?.toDouble(),
      dateUpdated: json['dateUpdated'] as String?,
      details: (json['details'] as List<dynamic>?)
          ?.map((e) => StockCountLineDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$StockCountDtoToJson(StockCountDto instance) =>
    <String, dynamic>{
      'companyId': instance.companyId,
      'branchId': instance.branchId,
      'stockcntId': instance.stockcntId,
      'cntType': instance.cntType,
      'status': instance.status,
      'stockcntDate': instance.stockcntDate,
      'whseCode': instance.whseCode,
      'totalItems': instance.totalItems,
      'totalCountQty': instance.totalCountQty,
      'totalVarQty': instance.totalVarQty,
      'dateUpdated': instance.dateUpdated,
      'details': instance.details,
    };

StockCountSearchResponseDto _$StockCountSearchResponseDtoFromJson(
  Map<String, dynamic> json,
) => StockCountSearchResponseDto(
  content: (json['content'] as List<dynamic>)
      .map((e) => StockCountDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalElements: (json['totalElements'] as num).toInt(),
  totalPages: (json['totalPages'] as num).toInt(),
);

Map<String, dynamic> _$StockCountSearchResponseDtoToJson(
  StockCountSearchResponseDto instance,
) => <String, dynamic>{
  'content': instance.content,
  'totalElements': instance.totalElements,
  'totalPages': instance.totalPages,
};
