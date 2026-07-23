import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';

Product _product({
  bool isEnabled = true,
  bool isDiscontinued = false,
  double qtyOnHand = 10,
  double? reorderLevel,
}) {
  return Product(
    companyId: 'BAS',
    productTypeCode: 'BOOK',
    productCode: 'X',
    productBarcode: '',
    productTitle: '',
    productBrand: '',
    isEnabled: isEnabled,
    isDiscontinued: isDiscontinued,
    priceWithGst: 0,
    priceWithoutGst: 0,
    cost: 0,
    uom: '',
    qtyOnHand: qtyOnHand,
    reorderLevel: reorderLevel,
  );
}

void main() {
  group('Product.status', () {
    test('active when enabled and not discontinued', () {
      expect(_product(isEnabled: true, isDiscontinued: false).status, ProductStatus.active);
    });

    test('inactive when not enabled', () {
      expect(_product(isEnabled: false, isDiscontinued: false).status, ProductStatus.inactive);
    });

    test('discontinued takes priority over inactive', () {
      expect(_product(isEnabled: false, isDiscontinued: true).status, ProductStatus.discontinued);
    });

    test('discontinued even when enabled', () {
      expect(_product(isEnabled: true, isDiscontinued: true).status, ProductStatus.discontinued);
    });
  });

  group('Product.stockLevel', () {
    test('out of stock when qty is zero', () {
      expect(_product(qtyOnHand: 0, reorderLevel: 5).stockLevel, StockLevel.outOfStock);
    });

    test('out of stock when qty is negative', () {
      expect(_product(qtyOnHand: -1, reorderLevel: 5).stockLevel, StockLevel.outOfStock);
    });

    test('low stock when qty is at or below reorder level', () {
      expect(_product(qtyOnHand: 5, reorderLevel: 5).stockLevel, StockLevel.lowStock);
      expect(_product(qtyOnHand: 3, reorderLevel: 5).stockLevel, StockLevel.lowStock);
    });

    test('in stock when qty is above reorder level', () {
      expect(_product(qtyOnHand: 10, reorderLevel: 5).stockLevel, StockLevel.inStock);
    });

    test('in stock when qty is positive and reorderLevel is null', () {
      expect(_product(qtyOnHand: 1, reorderLevel: null).stockLevel, StockLevel.inStock);
    });
  });

  test('heroTag is stable and unique per product identity', () {
    expect(_product().heroTag, 'product-image-BAS-BOOK-X');
  });
}
