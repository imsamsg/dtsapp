import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/presentation/widgets/product_badge.dart';

Product _product({bool isEnabled = true, bool isDiscontinued = false, double qtyOnHand = 10, double? reorderLevel}) {
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
  testWidgets('category badge shows the product type code', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProductBadge(product: _product(), kind: ProductBadgeKind.category)));
    expect(find.text('BOOK'), findsOneWidget);
  });

  testWidgets('stock badge shows Low Stock when qty is at reorder level', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductBadge(product: _product(qtyOnHand: 5, reorderLevel: 5), kind: ProductBadgeKind.stock)),
    );
    expect(find.text('Low Stock'), findsOneWidget);
  });

  testWidgets('stock badge shows Out of Stock when qty is zero', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProductBadge(product: _product(qtyOnHand: 0), kind: ProductBadgeKind.stock)));
    expect(find.text('Out of Stock'), findsOneWidget);
  });

  testWidgets('stock badge shows In Stock when qty is healthy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductBadge(product: _product(qtyOnHand: 20, reorderLevel: 5), kind: ProductBadgeKind.stock)),
    );
    expect(find.text('In Stock'), findsOneWidget);
  });

  testWidgets('status badge shows Discontinued when isDiscontinued is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductBadge(product: _product(isDiscontinued: true), kind: ProductBadgeKind.status)),
    );
    expect(find.text('Discontinued'), findsOneWidget);
  });

  testWidgets('status badge shows Inactive when not enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductBadge(product: _product(isEnabled: false), kind: ProductBadgeKind.status)),
    );
    expect(find.text('Inactive'), findsOneWidget);
  });
}
