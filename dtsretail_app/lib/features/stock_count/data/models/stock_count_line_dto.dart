import 'package:json_annotation/json_annotation.dart';

part 'stock_count_line_dto.g.dart';

@JsonSerializable()
class StockCountLineDto {
  StockCountLineDto({
    required this.productCode,
    required this.productTypeCode,
    this.productTitle,
    this.productPriceWgst,
    this.productCost,
    required this.countQty,
    this.compQty,
    this.varQty,
  });

  final String productCode;
  final String productTypeCode;
  final String? productTitle;
  final double? productPriceWgst;
  final double? productCost;
  final double countQty;
  final double? compQty;
  final double? varQty;

  factory StockCountLineDto.fromJson(Map<String, dynamic> json) => _$StockCountLineDtoFromJson(json);
  Map<String, dynamic> toJson() => _$StockCountLineDtoToJson(this);
}
