import 'package:json_annotation/json_annotation.dart';

part 'product_dto.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class ProductDto {
  ProductDto({
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
    this.productBarcode,
    this.productTitle,
    this.productBrand,
    this.enableyn,
    this.productPriceWgst,
    this.productPriceWogst,
    this.productCost,
    this.productUOM,
    this.prodTotQtyOnHand,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String? productBarcode;
  final String? productTitle;
  final String? productBrand;
  final bool? enableyn;
  final double? productPriceWgst;
  final double? productPriceWogst;
  final double? productCost;
  final String? productUOM;
  final double? prodTotQtyOnHand;

  factory ProductDto.fromJson(Map<String, dynamic> json) => _$ProductDtoFromJson(json);
}

@JsonSerializable()
class ProductSearchResponseDto {
  ProductSearchResponseDto({
    required this.content,
    required this.totalElements,
    required this.totalPages,
  });

  final List<ProductDto> content;
  final int totalElements;
  final int totalPages;

  factory ProductSearchResponseDto.fromJson(Map<String, dynamic> json) => _$ProductSearchResponseDtoFromJson(json);
}
