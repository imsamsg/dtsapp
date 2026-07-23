import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/presentation/widgets/product_card.dart';

const _product = Product(
  companyId: 'BAS',
  productTypeCode: 'BOOK',
  productCode: 'X',
  productBarcode: '1234',
  productTitle: 'Test Product',
  productBrand: 'Acme',
  isEnabled: true,
  isDiscontinued: false,
  priceWithGst: 29.9,
  priceWithoutGst: 27.94,
  cost: 13.08,
  uom: 'CPY',
  qtyOnHand: 10,
);

void main() {
  testWidgets('shows title, brand, and price', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 400, child: ProductCard(product: _product, onTap: () {})))));

    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('\$29.90'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 400, child: ProductCard(product: _product, onTap: () => tapped = true)))));

    await tester.tap(find.byType(ProductCard));
    expect(tapped, isTrue);
  });

  testWidgets('does not show a status badge for an active product', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 400, child: ProductCard(product: _product, onTap: () {})))));
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('shows a Discontinued status badge when the product is discontinued', (tester) async {
    const discontinued = Product(
      companyId: 'BAS',
      productTypeCode: 'BOOK',
      productCode: 'X',
      productBarcode: '1234',
      productTitle: 'Test Product',
      productBrand: 'Acme',
      isEnabled: true,
      isDiscontinued: true,
      priceWithGst: 29.9,
      priceWithoutGst: 27.94,
      cost: 13.08,
      uom: 'CPY',
      qtyOnHand: 10,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 400, child: ProductCard(product: discontinued, onTap: () {})))));
    expect(find.text('Discontinued'), findsOneWidget);
  });
}
