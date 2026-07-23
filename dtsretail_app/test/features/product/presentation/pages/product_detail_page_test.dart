import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/api/api_exception.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/presentation/pages/product_detail_page.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_providers.dart';

const _product = Product(
  companyId: 'BAS',
  productTypeCode: 'BOOK',
  productCode: '2007786553',
  productBarcode: '2007786553',
  productTitle: 'Test Product',
  productBrand: 'NATIO',
  isEnabled: true,
  isDiscontinued: false,
  priceWithGst: 29.9,
  priceWithoutGst: 27.94,
  cost: 13.08,
  uom: 'CPY',
  qtyOnHand: 10,
);

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.error});
  final ApiException? error;

  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) async {
    if (error != null) throw error!;
    return _product;
  }
}

/// Grows the test surface so the hero image and every info-card row render
/// on screen at once. The default 800x600 test viewport is shorter than the
/// hero image alone (768x640 at aspectRatio 1.2), which pushes the rest of
/// the page below the fold; `SliverMultiBoxAdaptorElement.debugVisitOnstageChildren`
/// then treats those rows as offstage, so `find.text()` (skipOffstage: true
/// by default) reports them as not found even though they're built and
/// laid out. Mirrors `_growSurface` in `dashboard_page_test.dart`.
Future<void> _growSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  Widget buildPage(ProductRepository repo) {
    return ProviderScope(
      overrides: [productRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: ProductDetailPage(companyId: 'BAS', productTypeCode: 'BOOK', productCode: '2007786553'),
      ),
    );
  }

  testWidgets('shows a loading indicator while fetching', (tester) async {
    await tester.pumpWidget(buildPage(_FakeProductRepository()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows product details once loaded', (tester) async {
    await _growSurface(tester);
    await tester.pumpWidget(buildPage(_FakeProductRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('NATIO'), findsOneWidget);
    expect(find.text('\$29.90'), findsOneWidget);
    expect(find.text('BOOK'), findsOneWidget);
    expect(find.text('In Stock'), findsOneWidget);
  });

  testWidgets('shows an error view on failure', (tester) async {
    await tester.pumpWidget(
      buildPage(_FakeProductRepository(error: const NetworkException('Unable to reach the server. Check your connection.'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to reach the server. Check your connection.'), findsOneWidget);
  });

  testWidgets('never shows an edit icon (read-only per foundation spec)', (tester) async {
    await _growSurface(tester);
    await tester.pumpWidget(buildPage(_FakeProductRepository()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
  });
}
