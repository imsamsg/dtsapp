// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_count_line_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockCountLineDto _$StockCountLineDtoFromJson(Map<String, dynamic> json) =>
    StockCountLineDto(
      productCode: json['productCode'] as String,
      productTypeCode: json['productTypeCode'] as String,
      productTitle: json['productTitle'] as String?,
      productPriceWgst: (json['productPriceWgst'] as num?)?.toDouble(),
      productCost: (json['productCost'] as num?)?.toDouble(),
      countQty: (json['countQty'] as num).toDouble(),
      compQty: (json['compQty'] as num?)?.toDouble(),
      varQty: (json['varQty'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$StockCountLineDtoToJson(StockCountLineDto instance) =>
    <String, dynamic>{
      'productCode': instance.productCode,
      'productTypeCode': instance.productTypeCode,
      'productTitle': instance.productTitle,
      'productPriceWgst': instance.productPriceWgst,
      'productCost': instance.productCost,
      'countQty': instance.countQty,
      'compQty': instance.compQty,
      'varQty': instance.varQty,
    };
