import '../models/stock_count_dto.dart';
import '../models/stock_count_line_dto.dart';
import '../models/warehouse_dto.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_line.dart';
import '../../domain/entities/warehouse.dart';

extension StockCountLineDtoMapper on StockCountLineDto {
  StockCountLine toDomain() {
    return StockCountLine(
      productCode: productCode,
      productTypeCode: productTypeCode,
      productTitle: productTitle ?? '',
      priceWithGst: productPriceWgst ?? 0,
      cost: productCost ?? 0,
      countQty: countQty,
    );
  }

  static StockCountLineDto fromDomain(StockCountLine line) {
    return StockCountLineDto(
      productCode: line.productCode,
      productTypeCode: line.productTypeCode,
      productTitle: line.productTitle,
      productPriceWgst: line.priceWithGst,
      productCost: line.cost,
      countQty: line.countQty,
    );
  }
}

extension StockCountDtoMapper on StockCountDto {
  StockCount toDomain() {
    return StockCount(
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId ?? '',
      cntType: cntType,
      status: status,
      stockcntDate: stockcntDate ?? '',
      whseCode: whseCode,
      totalItems: totalItems ?? (details?.length ?? 0),
      totalCountQty: totalCountQty ?? 0,
      totalVarQty: totalVarQty ?? 0,
      dateUpdated: dateUpdated ?? '',
      lines: (details ?? const []).map((d) => d.toDomain()).toList(),
    );
  }
}

extension StockCountSearchResponseDtoMapper on StockCountSearchResponseDto {
  StockCountSearchResult toDomain() {
    return StockCountSearchResult(
      items: content.map((dto) => dto.toDomain()).toList(),
      totalElements: totalElements,
      totalPages: totalPages,
    );
  }
}

extension WarehouseDtoMapper on WarehouseDto {
  Warehouse toDomain() {
    return Warehouse(code: whse, description: description ?? whse, branchCode: branchCode ?? '');
  }
}

StockCountDto stockCountToCreateDto({
  required String companyId,
  required String branchId,
  required String cntType,
  required String whseCode,
  required List<StockCountLine> lines,
}) {
  return StockCountDto(
    companyId: companyId,
    branchId: branchId,
    cntType: cntType,
    status: 'OPEN',
    whseCode: whseCode,
    details: lines.map(StockCountLineDtoMapper.fromDomain).toList(),
  );
}
