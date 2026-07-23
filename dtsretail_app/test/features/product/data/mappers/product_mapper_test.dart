import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/data/models/product_dto.dart';
import 'package:dtsretail_app/features/product/data/mappers/product_mapper.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';

void main() {
  test('ProductDto.toDomain maps fields and defaults missing numeric fields to 0', () {
    final dto = ProductDto(
      companyId: 'BAS',
      productTypeCode: 'BOOK',
      productCode: '2007786553',
      productBarcode: '2007786553',
      productTitle: 'Test Title',
      productBrand: 'NATIO',
      enableyn: true,
      discontinueYN: false,
      productPriceWgst: 29.9,
      productPriceWogst: 27.94,
      productCost: 13.08,
      productUOM: 'CPY',
      prodTotQtyOnHand: 10.0,
      prodImage: 'https://example.com/image.jpg',
      productReorderLevel: 5.0,
    );

    final product = dto.toDomain();

    expect(product.companyId, 'BAS');
    expect(product.productBarcode, '2007786553');
    expect(product.priceWithGst, 29.9);
    expect(product.qtyOnHand, 10.0);
    expect(product.imageUrl, 'https://example.com/image.jpg');
    expect(product.isDiscontinued, false);
    expect(product.reorderLevel, 5.0);
    expect(product.status, ProductStatus.active);
    expect(product.stockLevel, StockLevel.inStock);
  });

  test('ProductDto.toDomain defaults null optional fields safely', () {
    final dto = ProductDto(companyId: 'BAS', productTypeCode: 'BOOK', productCode: 'X');
    final product = dto.toDomain();

    expect(product.productTitle, '');
    expect(product.priceWithGst, 0);
    expect(product.isEnabled, true);
    expect(product.isDiscontinued, false);
    expect(product.imageUrl, isNull);
    expect(product.reorderLevel, isNull);
  });

  test('ProductDto.toDomain treats an empty prodImage as no image', () {
    final dto = ProductDto(companyId: 'BAS', productTypeCode: 'BOOK', productCode: 'X', prodImage: '');
    expect(dto.toDomain().imageUrl, isNull);
  });

  test('ProductDto.toDomain falls back to productSafetyStock when productReorderLevel is absent', () {
    final dto = ProductDto(companyId: 'BAS', productTypeCode: 'BOOK', productCode: 'X', productSafetyStock: 3.0);
    expect(dto.toDomain().reorderLevel, 3.0);
  });
}
