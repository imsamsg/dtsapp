// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductDto _$ProductDtoFromJson(Map<String, dynamic> json) => ProductDto(
  companyId: json['companyId'] as String,
  productTypeCode: json['productTypeCode'] as String,
  productCode: json['productCode'] as String,
  productBarcode: json['productBarcode'] as String?,
  productTitle: json['productTitle'] as String?,
  productBrand: json['productBrand'] as String?,
  enableyn: json['enableyn'] as bool?,
  productPriceWgst: (json['productPriceWgst'] as num?)?.toDouble(),
  productPriceWogst: (json['productPriceWogst'] as num?)?.toDouble(),
  productCost: (json['productCost'] as num?)?.toDouble(),
  productUOM: json['productUOM'] as String?,
  prodTotQtyOnHand: (json['prodTotQtyOnHand'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ProductDtoToJson(ProductDto instance) =>
    <String, dynamic>{
      'companyId': instance.companyId,
      'productTypeCode': instance.productTypeCode,
      'productCode': instance.productCode,
      'productBarcode': instance.productBarcode,
      'productTitle': instance.productTitle,
      'productBrand': instance.productBrand,
      'enableyn': instance.enableyn,
      'productPriceWgst': instance.productPriceWgst,
      'productPriceWogst': instance.productPriceWogst,
      'productCost': instance.productCost,
      'productUOM': instance.productUOM,
      'prodTotQtyOnHand': instance.prodTotQtyOnHand,
    };

ProductSearchResponseDto _$ProductSearchResponseDtoFromJson(
  Map<String, dynamic> json,
) => ProductSearchResponseDto(
  content: (json['content'] as List<dynamic>)
      .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalElements: (json['totalElements'] as num).toInt(),
  totalPages: (json['totalPages'] as num).toInt(),
);

Map<String, dynamic> _$ProductSearchResponseDtoToJson(
  ProductSearchResponseDto instance,
) => <String, dynamic>{
  'content': instance.content,
  'totalElements': instance.totalElements,
  'totalPages': instance.totalPages,
};
