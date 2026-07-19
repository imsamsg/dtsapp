import 'package:json_annotation/json_annotation.dart';
import 'stock_count_line_dto.dart';

part 'stock_count_dto.g.dart';

@JsonSerializable()
class StockCountDto {
  StockCountDto({
    required this.companyId,
    required this.branchId,
    this.stockcntId,
    required this.cntType,
    required this.status,
    this.stockcntDate,
    required this.whseCode,
    this.totalItems,
    this.totalCountQty,
    this.totalVarQty,
    this.dateUpdated,
    this.details,
  });

  final String companyId;
  final String branchId;
  final String? stockcntId;
  final String cntType;
  final String status;
  final String? stockcntDate;
  final String whseCode;
  final int? totalItems;
  final double? totalCountQty;
  final double? totalVarQty;
  final String? dateUpdated;
  final List<StockCountLineDto>? details;

  factory StockCountDto.fromJson(Map<String, dynamic> json) => _$StockCountDtoFromJson(json);
  Map<String, dynamic> toJson() => _$StockCountDtoToJson(this);
}

@JsonSerializable()
class StockCountSearchResponseDto {
  StockCountSearchResponseDto({required this.content, required this.totalElements, required this.totalPages});

  final List<StockCountDto> content;
  final int totalElements;
  final int totalPages;

  factory StockCountSearchResponseDto.fromJson(Map<String, dynamic> json) => _$StockCountSearchResponseDtoFromJson(json);
}
