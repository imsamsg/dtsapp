import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/stock_count/data/models/stock_count_dto.dart';
import 'package:dtsretail_app/features/stock_count/data/models/stock_count_line_dto.dart';
import 'package:dtsretail_app/features/stock_count/data/mappers/stock_count_mapper.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';

void main() {
  test('StockCountDto.toDomain maps header and line items', () {
    final dto = StockCountDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      stockcntId: 'SC0089',
      cntType: 'POSCNT',
      status: 'OPEN',
      stockcntDate: '2020-08-02',
      whseCode: 'BBPOS',
      totalItems: 1,
      totalCountQty: 45.0,
      totalVarQty: -2.0,
      dateUpdated: '2020-08-02T10:00:00',
      details: [
        StockCountLineDto(
          productCode: '12016',
          productTypeCode: 'MAGAZINE',
          productTitle: 'ARCHIVE 1 /2016',
          productPriceWgst: 23.0,
          productCost: 12.7,
          countQty: 45.0,
        ),
      ],
    );

    final domain = dto.toDomain();

    expect(domain.stockcntId, 'SC0089');
    expect(domain.isOpen, isTrue);
    expect(domain.lines, hasLength(1));
    expect(domain.lines.first.productTitle, 'ARCHIVE 1 /2016');
  });

  test('stockCountToCreateDto builds a create-ready DTO with OPEN status', () {
    final dto = stockCountToCreateDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      cntType: 'CNT',
      whseCode: 'BBPOS',
      lines: const [
        StockCountLine(
          productCode: '2007786553',
          productTypeCode: 'BOOK',
          productTitle: 'Test Product',
          priceWithGst: 29.9,
          cost: 13.08,
          countQty: 10,
        ),
      ],
    );

    expect(dto.status, 'OPEN');
    expect(dto.details, hasLength(1));
    expect(dto.details!.first.productCode, '2007786553');
  });
}
