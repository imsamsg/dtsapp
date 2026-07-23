# Product Catalog Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `ProductListPage` (grid, real images, badges, debounced search, sort, infinite scroll, pull-to-refresh) and `ProductDetailPage` (hero image, badges, card-based layout), backed by real `dtsapi` fields the Flutter side currently discards.

**Architecture:** Extend the existing `data / domain / presentation` layering — `ProductDto`/`Product`/mapper gain four new fields plus two computed getters (`status`, `stockLevel`); the repository chain gains `sortBy`/`sortDirection`; a new `StateNotifier`-backed `ProductListNotifier` replaces the old single-page `FutureProvider.family` to support infinite scroll; two new small shared presentation widgets (`ProductBadge`, `ProductImage`) eliminate duplication between the grid card and the detail page.

**Tech Stack:** Flutter 3.44.6 / Dart ^3.8.1, Riverpod (`flutter_riverpod`) — no new packages.

## Global Constraints

- Brand palette additions (from `designs/appdesign.png`, previously unused tokens): `AppColors.warning` = `#F59E0B` (Low Stock badge), `AppColors.neutral` = `#64748B` (Inactive badge, secondary text). Category badges use existing `AppColors.accent` (`#14BBA6`); In Stock / Active use existing `AppColors.primary`; Out of Stock / Discontinued use existing `AppColors.danger`.
- Backend search endpoint (`GET /inventory/products/search`) accepts only `companyId`, `searchString`, `searchKey`, `page`, `size`, `sortBy`, `sortDirection` — confirmed by reading `ProductController.java` directly. No category/brand/status/stock/price/date/warehouse filter params exist. Do not build a filter panel or counted status tabs.
- `sortBy` is passed raw into `Sort.by(direction, sortBy)` server-side — must be a real JPA entity field name. Only use `'productCode'`, `'productTitle'`, `'productPriceWgst'` (all confirmed present on the `Product` JPA entity).
- Sort options, exact set (label → sortBy/sortDirection), in this order: Code A-Z (`productCode`/`asc`, the default) → Title A-Z (`productTitle`/`asc`) → Title Z-A (`productTitle`/`desc`) → Price Low-High (`productPriceWgst`/`asc`) → Price High-Low (`productPriceWgst`/`desc`).
- `reorderLevel` on the domain `Product` entity is `productReorderLevel ?? productSafetyStock` from the DTO (fallback chain) — resolves an ambiguity in the spec, which named both fields as real thresholds without specifying how they combine. If both are null, a product is never flagged "low stock" — no invented default threshold.
- Existing widget/behavior compatibility: `find.byType(TextField)` and `Icons.qr_code_scanner` must remain valid finders in `ProductListPage`; pressing the keyboard's "done" action must still submit immediately (existing tests rely on this).
- Out of scope, do not add: filter panel, counted status tabs, cart/checkout icons, an edit button on the detail page, multi-image carousel, any new image-caching package (plain `Image.network` only), a generic `PagedListNotifier<T>` base class (no second module needs paging yet).
- All `flutter`/`dart` commands below assume the working directory is `dtsretail_app/` (the Flutter project root inside the worktree).

---

## Task 1: Data layer — entity, DTO, mapper, and sortBy/sortDirection support

**Files:**
- Modify: `dtsretail_app/lib/features/product/domain/entities/product.dart`
- Modify: `dtsretail_app/lib/features/product/data/models/product_dto.dart`
- Modify: `dtsretail_app/lib/features/product/data/mappers/product_mapper.dart`
- Modify: `dtsretail_app/lib/features/product/domain/repository/product_repository.dart`
- Modify: `dtsretail_app/lib/features/product/data/repository/product_repository_impl.dart`
- Modify: `dtsretail_app/lib/features/product/data/datasource/remote/product_remote_datasource.dart`
- Modify: `dtsretail_app/lib/features/product/domain/usecases/search_products_usecase.dart`
- Modify (compile-required, not a redesign — see Step 8): `dtsretail_app/test/features/product/presentation/product_list_page_test.dart`
- Modify (compile-required, not a redesign — see Step 8): `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart`
- Modify: `dtsretail_app/test/features/product/data/mappers/product_mapper_test.dart`
- Test: `dtsretail_app/test/features/product/domain/entities/product_test.dart` (new)
- Test: `dtsretail_app/test/features/product/domain/usecases/search_products_usecase_test.dart` (new)

**Interfaces:**
- Produces: `Product.imageUrl` (`String?`), `Product.isDiscontinued` (`bool`, required), `Product.reorderLevel` (`double?`), `Product.status` (`ProductStatus` getter: `active`/`inactive`/`discontinued`), `Product.stockLevel` (`StockLevel` getter: `inStock`/`lowStock`/`outOfStock`), `Product.heroTag` (`String` getter). `ProductRepository.search(...)` / `SearchProductsUsecase.call(...)` gain `String sortBy = 'productCode'`, `String sortDirection = 'asc'`.
- Consumes: nothing new from other tasks (this task is foundational — Tasks 2-6 consume its outputs).

- [ ] **Step 1: Update the `Product` entity**

Replace the full contents of `dtsretail_app/lib/features/product/domain/entities/product.dart`:

```dart
enum ProductStatus { active, inactive, discontinued }

enum StockLevel { inStock, lowStock, outOfStock }

class Product {
  const Product({
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
    required this.productBarcode,
    required this.productTitle,
    required this.productBrand,
    required this.isEnabled,
    required this.isDiscontinued,
    required this.priceWithGst,
    required this.priceWithoutGst,
    required this.cost,
    required this.uom,
    required this.qtyOnHand,
    this.imageUrl,
    this.reorderLevel,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String productBarcode;
  final String productTitle;
  final String productBrand;
  final bool isEnabled;
  final bool isDiscontinued;
  final double priceWithGst;
  final double priceWithoutGst;
  final double cost;
  final String uom;
  final double qtyOnHand;
  final String? imageUrl;
  final double? reorderLevel;

  /// Stable per-product identity for [Hero] transitions between the grid
  /// card and the detail page.
  String get heroTag => 'product-image-$companyId-$productTypeCode-$productCode';

  ProductStatus get status {
    if (isDiscontinued) return ProductStatus.discontinued;
    if (!isEnabled) return ProductStatus.inactive;
    return ProductStatus.active;
  }

  StockLevel get stockLevel {
    if (qtyOnHand <= 0) return StockLevel.outOfStock;
    if (reorderLevel != null && qtyOnHand <= reorderLevel!) return StockLevel.lowStock;
    return StockLevel.inStock;
  }
}

class ProductSearchResult {
  const ProductSearchResult({required this.items, required this.totalElements, required this.totalPages});

  final List<Product> items;
  final int totalElements;
  final int totalPages;
}
```

- [ ] **Step 2: Update `ProductDto`**

Replace the full contents of `dtsretail_app/lib/features/product/data/models/product_dto.dart`:

```dart
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
    this.discontinueYN,
    this.productPriceWgst,
    this.productPriceWogst,
    this.productCost,
    this.productUOM,
    this.prodTotQtyOnHand,
    this.prodImage,
    this.productReorderLevel,
    this.productSafetyStock,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String? productBarcode;
  final String? productTitle;
  final String? productBrand;
  final bool? enableyn;
  final bool? discontinueYN;
  final double? productPriceWgst;
  final double? productPriceWogst;
  final double? productCost;
  final String? productUOM;
  final double? prodTotQtyOnHand;
  final String? prodImage;
  final double? productReorderLevel;
  final double? productSafetyStock;

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
```

- [ ] **Step 3: Regenerate the generated JSON serialization code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: completes without errors, `product_dto.g.dart` now includes `discontinueYN`, `prodImage`, `productReorderLevel`, `productSafetyStock` in both the `fromJson` and `toJson` generated functions.

- [ ] **Step 4: Update `product_mapper.dart`**

Replace the full contents of `dtsretail_app/lib/features/product/data/mappers/product_mapper.dart`:

```dart
import '../models/product_dto.dart';
import '../../domain/entities/product.dart';

extension ProductDtoMapper on ProductDto {
  Product toDomain() {
    return Product(
      companyId: companyId,
      productTypeCode: productTypeCode,
      productCode: productCode,
      productBarcode: productBarcode ?? '',
      productTitle: productTitle ?? '',
      productBrand: productBrand ?? '',
      isEnabled: enableyn ?? true,
      isDiscontinued: discontinueYN ?? false,
      priceWithGst: productPriceWgst ?? 0,
      priceWithoutGst: productPriceWogst ?? 0,
      cost: productCost ?? 0,
      uom: productUOM ?? '',
      qtyOnHand: prodTotQtyOnHand ?? 0,
      imageUrl: (prodImage != null && prodImage!.isNotEmpty) ? prodImage : null,
      reorderLevel: productReorderLevel ?? productSafetyStock,
    );
  }
}

extension ProductSearchResponseDtoMapper on ProductSearchResponseDto {
  ProductSearchResult toDomain() {
    return ProductSearchResult(
      items: content.map((dto) => dto.toDomain()).toList(),
      totalElements: totalElements,
      totalPages: totalPages,
    );
  }
}
```

- [ ] **Step 5: Add `sortBy`/`sortDirection` through the repository chain**

In `dtsretail_app/lib/features/product/domain/repository/product_repository.dart`, replace the `search` method signature:

```dart
abstract interface class ProductRepository {
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey,
    int page,
    int size,
    String sortBy,
    String sortDirection,
  });

  Future<Product> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  });
}
```

In `dtsretail_app/lib/features/product/data/repository/product_repository_impl.dart`, replace the `search` override:

```dart
  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    final dto = await _remote.search(
      companyId: companyId,
      searchString: searchString,
      searchKey: searchKey,
      page: page,
      size: size,
      sortBy: sortBy,
      sortDirection: sortDirection,
    );
    return dto.toDomain();
  }
```

In `dtsretail_app/lib/features/product/data/datasource/remote/product_remote_datasource.dart`, replace the `search` method:

```dart
  Future<ProductSearchResponseDto> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) {
    return guardApiCall(() async {
      final response = await _dio.get('/inventory/products/search', queryParameters: {
        'companyId': companyId,
        if (searchString != null && searchString.isNotEmpty) 'searchString': searchString,
        'searchKey': searchKey,
        'page': page,
        'size': size,
        'sortBy': sortBy,
        'sortDirection': sortDirection,
      });
      return ProductSearchResponseDto.fromJson(response.data as Map<String, dynamic>);
    });
  }
```

In `dtsretail_app/lib/features/product/domain/usecases/search_products_usecase.dart`, replace the `call` method:

```dart
  Future<ProductSearchResult> call({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) {
    return _repository.search(
      companyId: companyId,
      searchString: searchString,
      searchKey: searchKey,
      page: page,
      size: size,
      sortBy: sortBy,
      sortDirection: sortDirection,
    );
  }
```

- [ ] **Step 6: Fix the two `Product(...)`-constructing test fixtures (compile-required)**

Adding a *required* `isDiscontinued` field to `Product` breaks any direct construction site. Two exist outside this feature's own tests:

In `dtsretail_app/test/features/product/presentation/product_list_page_test.dart`, find the `_testProduct` constant and add one field (do not change anything else in this file yet — its full redesign happens in Task 5):

```dart
const _testProduct = Product(
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
```

In `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart`, find `_scannedProduct` (around line 158) and add the same field:

```dart
const _scannedProduct = Product(
  companyId: 'BAS',
  productTypeCode: 'BOOK',
  productCode: 'P002',
  productBarcode: '1234567890',
  productTitle: 'Scanned Product',
  productBrand: 'Acme',
  isEnabled: true,
  isDiscontinued: false,
  priceWithGst: 12,
  priceWithoutGst: 11,
  cost: 6,
  uom: 'EA',
  qtyOnHand: 50,
);
```

- [ ] **Step 7: Fix the two `implements ProductRepository` fakes' method signatures (compile-required)**

Both `_FakeProductRepository` classes below `implements ProductRepository` and must declare the two new named parameters — same file, same class as Step 6's product fixtures.

In `dtsretail_app/test/features/product/presentation/product_list_page_test.dart`, update the fake's `search` override signature only (no behavior change yet — Task 5 rewrites this whole class):

```dart
  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    lastSearchString = searchString;
    if (error != null) throw error!;
    return ProductSearchResult(items: [_testProduct], totalElements: 1, totalPages: 1);
  }
```

In `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart`, update the fake's `search` override signature the same way:

```dart
  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    return ProductSearchResult(items: [_product], totalElements: 1, totalPages: 1);
  }
```

- [ ] **Step 8: Run the full suite to confirm the compile-fix steps are complete**

```bash
flutter test
```

Expected: all tests pass (this confirms Steps 6-7 fully addressed the blast radius of the entity/interface changes — no other file constructs `Product` directly or implements `ProductRepository`).

- [ ] **Step 9: Update `product_mapper_test.dart`**

Replace the full contents of `dtsretail_app/test/features/product/data/mappers/product_mapper_test.dart`:

```dart
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
```

- [ ] **Step 10: Write `product_test.dart` (new — TDD for the entity getters)**

Create `dtsretail_app/test/features/product/domain/entities/product_test.dart`:

```dart
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
```

Run it and confirm it passes (the entity code from Step 1 already exists, so this should pass immediately — it's still useful, real coverage, just not strict red-green since Step 1 preceded it in this task):

```bash
flutter test test/features/product/domain/entities/product_test.dart
```

Expected: `00:0X +11: All tests passed!`

- [ ] **Step 11: Write `search_products_usecase_test.dart` (new)**

Create `dtsretail_app/test/features/product/domain/usecases/search_products_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/domain/usecases/search_products_usecase.dart';

class _FakeProductRepository implements ProductRepository {
  String? capturedSortBy;
  String? capturedSortDirection;
  int? capturedPage;

  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    capturedSortBy = sortBy;
    capturedSortDirection = sortDirection;
    capturedPage = page;
    return const ProductSearchResult(items: [], totalElements: 0, totalPages: 0);
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

void main() {
  test('SearchProductsUsecase defaults sortBy/sortDirection to productCode/asc', () async {
    final repo = _FakeProductRepository();
    final usecase = SearchProductsUsecase(repo);

    await usecase(companyId: 'BAS');

    expect(repo.capturedSortBy, 'productCode');
    expect(repo.capturedSortDirection, 'asc');
  });

  test('SearchProductsUsecase forwards a custom sortBy/sortDirection/page', () async {
    final repo = _FakeProductRepository();
    final usecase = SearchProductsUsecase(repo);

    await usecase(companyId: 'BAS', sortBy: 'productPriceWgst', sortDirection: 'desc', page: 2);

    expect(repo.capturedSortBy, 'productPriceWgst');
    expect(repo.capturedSortDirection, 'desc');
    expect(repo.capturedPage, 2);
  });
}
```

```bash
flutter test test/features/product/domain/usecases/search_products_usecase_test.dart
```

Expected: `00:0X +2: All tests passed!`

- [ ] **Step 12: Run the full suite**

```bash
flutter test
```

Expected: all tests pass, no analyzer warnings from `flutter analyze`.

- [ ] **Step 13: Commit**

```bash
git add lib/features/product/domain/entities/product.dart lib/features/product/data/models/product_dto.dart lib/features/product/data/models/product_dto.g.dart lib/features/product/data/mappers/product_mapper.dart lib/features/product/domain/repository/product_repository.dart lib/features/product/data/repository/product_repository_impl.dart lib/features/product/data/datasource/remote/product_remote_datasource.dart lib/features/product/domain/usecases/search_products_usecase.dart test/features/product/presentation/product_list_page_test.dart test/features/stock_count/presentation/stock_count_form_page_test.dart test/features/product/data/mappers/product_mapper_test.dart test/features/product/domain/entities/product_test.dart test/features/product/domain/usecases/search_products_usecase_test.dart
git commit -m "Extend product data layer: image/status/stock-level fields, sortBy/sortDirection support"
```

---

## Task 2: Shared `ProductBadge` and `ProductImage` widgets

**Files:**
- Modify: `dtsretail_app/lib/app/theme/app_theme.dart`
- Create: `dtsretail_app/lib/features/product/presentation/widgets/product_badge.dart`
- Create: `dtsretail_app/lib/features/product/presentation/widgets/product_image.dart`
- Test: `dtsretail_app/test/features/product/presentation/widgets/product_badge_test.dart` (new)
- Test: `dtsretail_app/test/features/product/presentation/widgets/product_image_test.dart` (new)

**Interfaces:**
- Consumes: `Product.status`, `Product.stockLevel`, `Product.productTypeCode`, `Product.heroTag`, `Product.imageUrl` (Task 1).
- Produces: `ProductBadge({required Product product, required ProductBadgeKind kind})` where `ProductBadgeKind` is `category | status | stock`. `ProductImage({required String? imageUrl, required String heroTag, double borderRadius = 12, double fallbackIconSize = 28})`. Both consumed by Tasks 4 and 6.

- [ ] **Step 1: Add the two new palette tokens**

In `dtsretail_app/lib/app/theme/app_theme.dart`, add two lines inside `AppColors` (after `danger`):

```dart
  static const warning = Color(0xFFF59E0B); // low-stock badge
  static const neutral = Color(0xFF64748B); // inactive-status badge, secondary text
```

- [ ] **Step 2: Write the failing `ProductBadge` test**

Create `dtsretail_app/test/features/product/presentation/widgets/product_badge_test.dart`:

```dart
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
```

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/features/product/presentation/widgets/product_badge_test.dart
```

Expected: FAIL to compile — `product_badge.dart` doesn't exist yet.

- [ ] **Step 4: Implement `ProductBadge`**

Create `dtsretail_app/lib/features/product/presentation/widgets/product_badge.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/product.dart';

enum ProductBadgeKind { category, status, stock }

class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key, required this.product, required this.kind});

  final Product product;
  final ProductBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  (String, Color) _labelAndColor() {
    switch (kind) {
      case ProductBadgeKind.category:
        return (product.productTypeCode, AppColors.accent);
      case ProductBadgeKind.status:
        switch (product.status) {
          case ProductStatus.active:
            return ('Active', AppColors.primary);
          case ProductStatus.inactive:
            return ('Inactive', AppColors.neutral);
          case ProductStatus.discontinued:
            return ('Discontinued', AppColors.danger);
        }
      case ProductBadgeKind.stock:
        switch (product.stockLevel) {
          case StockLevel.inStock:
            return ('In Stock', AppColors.primary);
          case StockLevel.lowStock:
            return ('Low Stock', AppColors.warning);
          case StockLevel.outOfStock:
            return ('Out of Stock', AppColors.danger);
        }
    }
  }
}
```

- [ ] **Step 5: Run it to verify it passes**

```bash
flutter test test/features/product/presentation/widgets/product_badge_test.dart
```

Expected: `00:0X +6: All tests passed!`

- [ ] **Step 6: Write the failing `ProductImage` test**

Create `dtsretail_app/test/features/product/presentation/widgets/product_image_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/presentation/widgets/product_image.dart';

void main() {
  testWidgets('shows the fallback icon when imageUrl is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(imageUrl: null, heroTag: 'tag-1')));
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('shows the fallback icon when imageUrl is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(imageUrl: '', heroTag: 'tag-2')));
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('wraps its content in a Hero with the given tag', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductImage(imageUrl: null, heroTag: 'unique-tag')));
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'unique-tag');
  });
}
```

- [ ] **Step 7: Run it to verify it fails**

```bash
flutter test test/features/product/presentation/widgets/product_image_test.dart
```

Expected: FAIL to compile — `product_image.dart` doesn't exist yet.

- [ ] **Step 8: Implement `ProductImage`**

Create `dtsretail_app/lib/features/product/presentation/widgets/product_image.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.borderRadius = 12,
    this.fallbackIconSize = 28,
  });

  final String? imageUrl;
  final String heroTag;
  final double borderRadius;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: (imageUrl == null || imageUrl!.isEmpty) ? _fallback() : _networkImage(imageUrl!),
      ),
    );
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surfaceTint,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, size: fallbackIconSize, color: AppColors.primary.withValues(alpha: 0.4)),
    );
  }
}
```

- [ ] **Step 9: Run it to verify it passes**

```bash
flutter test test/features/product/presentation/widgets/product_image_test.dart
```

Expected: `00:0X +3: All tests passed!`

- [ ] **Step 10: Run the full suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 11: Commit**

```bash
git add lib/app/theme/app_theme.dart lib/features/product/presentation/widgets/product_badge.dart lib/features/product/presentation/widgets/product_image.dart test/features/product/presentation/widgets/product_badge_test.dart test/features/product/presentation/widgets/product_image_test.dart
git commit -m "Add shared ProductBadge and ProductImage widgets, warning/neutral palette tokens"
```

---

## Task 3: `ProductListNotifier` — infinite-scroll pagination controller

**Files:**
- Create: `dtsretail_app/lib/features/product/presentation/providers/product_list_notifier.dart`
- Test: `dtsretail_app/test/features/product/presentation/providers/product_list_notifier_test.dart` (new)

**Interfaces:**
- Consumes: `searchProductsUsecaseProvider` (existing, from `product_providers.dart`, untouched by this task), `SearchProductsUsecase.call(...)` (Task 1's `sortBy`/`sortDirection` signature).
- Produces: `ProductListQuery({required companyId, required searchString, searchKey = 0, sortBy = 'productCode', sortDirection = 'asc'})` (value type, `==`/`hashCode` over all 5 fields), `ProductListState({items = const [], isLoading = false, isLoadingMore = false, hasMore = true, error, page = 0})`, `ProductListNotifier` with `Future<void> refresh()` and `Future<void> loadMore()`, `productListProvider = StateNotifierProvider.family<ProductListNotifier, ProductListState, ProductListQuery>`. Consumed by Task 5 (`ProductListPage`).

Note: this task deliberately does **not** touch `product_providers.dart`'s existing `ProductSearchQuery`/`productSearchProvider` — the *current* `product_list_page.dart` still depends on them and isn't rewritten until Task 5. Removing them here would leave the codebase non-compiling between this task and Task 5. `ProductListNotifier` and `productSearchProvider` coexist (the new notifier lives in its own file) until Task 5 switches the page over and removes the old ones in the same step.

- [ ] **Step 1: Write the failing `ProductListNotifier` tests**

Create `dtsretail_app/test/features/product/presentation/providers/product_list_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_list_notifier.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_providers.dart';

Product _product(String code) {
  return Product(
    companyId: 'BAS',
    productTypeCode: 'BOOK',
    productCode: code,
    productBarcode: '',
    productTitle: 'Product $code',
    productBrand: '',
    isEnabled: true,
    isDiscontinued: false,
    priceWithGst: 0,
    priceWithoutGst: 0,
    cost: 0,
    uom: '',
    qtyOnHand: 1,
  );
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._pages);
  final List<List<Product>> _pages;
  int calls = 0;
  int? errorOnPage;

  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    calls++;
    if (errorOnPage == page) throw StateError('simulated failure');
    final items = page < _pages.length ? _pages[page] : const <Product>[];
    return ProductSearchResult(items: items, totalElements: _pages.expand((p) => p).length, totalPages: _pages.length);
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  const query = ProductListQuery(companyId: 'BAS', searchString: '');

  test('loads page 0 on construction and derives hasMore from totalPages', () async {
    final repo = _FakeProductRepository([
      [_product('A'), _product('B')],
      [_product('C')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    container.read(productListProvider(query).notifier);
    await _flush();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A', 'B']);
    expect(state.hasMore, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('loadMore appends the next page and updates hasMore', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
      [_product('B')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();
    await notifier.loadMore();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A', 'B']);
    expect(state.hasMore, isFalse);
  });

  test('loadMore is a no-op once hasMore is false', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();
    await notifier.loadMore();
    final callsAfterFirstLoadMore = repo.calls;

    await notifier.loadMore();

    expect(repo.calls, callsAfterFirstLoadMore);
  });

  test('refresh replaces items rather than appending', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();
    await notifier.loadMore();

    await notifier.refresh();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A']);
  });

  test('a failed loadMore keeps existing items and resets isLoadingMore', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
      [_product('B')],
    ]);
    repo.errorOnPage = 1;
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();

    await notifier.loadMore();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A']);
    expect(state.isLoadingMore, isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/product/presentation/providers/product_list_notifier_test.dart
```

Expected: FAIL to compile — `product_list_notifier.dart` doesn't exist yet.

- [ ] **Step 3: Implement `ProductListNotifier`**

Create `dtsretail_app/lib/features/product/presentation/providers/product_list_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import 'product_providers.dart';

class ProductListQuery {
  const ProductListQuery({
    required this.companyId,
    required this.searchString,
    this.searchKey = 0,
    this.sortBy = 'productCode',
    this.sortDirection = 'asc',
  });

  final String companyId;
  final String searchString;
  final int searchKey;
  final String sortBy;
  final String sortDirection;

  @override
  bool operator ==(Object other) =>
      other is ProductListQuery &&
      other.companyId == companyId &&
      other.searchString == searchString &&
      other.searchKey == searchKey &&
      other.sortBy == sortBy &&
      other.sortDirection == sortDirection;

  @override
  int get hashCode => Object.hash(companyId, searchString, searchKey, sortBy, sortDirection);
}

class ProductListState {
  const ProductListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
  });

  final List<Product> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final int page;

  /// Note: does not carry [error] through — [error] is only ever set via a
  /// fresh [ProductListState] construction in [ProductListNotifier.refresh],
  /// so any successful copyWith implicitly clears a stale error.
  ProductListState copyWith({
    List<Product>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
  }) {
    return ProductListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  ProductListNotifier(this._ref, this.query) : super(const ProductListState()) {
    refresh();
  }

  final Ref _ref;
  final ProductListQuery query;
  static const _pageSize = 20;

  Future<void> refresh() async {
    state = const ProductListState(isLoading: true);
    try {
      final result = await _search(page: 0);
      state = ProductListState(items: result.items, hasMore: 1 < result.totalPages, page: 0);
    } catch (error) {
      state = ProductListState(error: error);
    }
  }

  /// A failed [loadMore] deliberately keeps existing items and does not set
  /// [ProductListState.error] — that field's meaning is "the whole list
  /// failed to load" (drives [AppErrorView] in the page). A load-more
  /// failure instead silently resets [ProductListState.isLoadingMore],
  /// letting the next near-bottom scroll retry.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _search(page: nextPage);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: nextPage + 1 < result.totalPages,
        page: nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<ProductSearchResult> _search({required int page}) {
    return _ref.read(searchProductsUsecaseProvider)(
      companyId: query.companyId,
      searchString: query.searchString.isEmpty ? null : query.searchString,
      searchKey: query.searchKey,
      page: page,
      size: _pageSize,
      sortBy: query.sortBy,
      sortDirection: query.sortDirection,
    );
  }
}

final productListProvider = StateNotifierProvider.family<ProductListNotifier, ProductListState, ProductListQuery>(
  (ref, query) => ProductListNotifier(ref, query),
);
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/product/presentation/providers/product_list_notifier_test.dart
```

Expected: `00:0X +5: All tests passed!`

- [ ] **Step 5: Run the full suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/product/presentation/providers/product_list_notifier.dart test/features/product/presentation/providers/product_list_notifier_test.dart
git commit -m "Add ProductListNotifier: infinite-scroll pagination controller"
```

---

## Task 4: `ProductCard` redesign (grid item)

**Files:**
- Modify: `dtsretail_app/lib/features/product/presentation/widgets/product_card.dart`
- Test: `dtsretail_app/test/features/product/presentation/widgets/product_card_test.dart` (new)

**Interfaces:**
- Consumes: `ProductBadge`, `ProductImage` (Task 2), `Product.status`, `Product.heroTag` (Task 1).
- Produces: `ProductCard({required Product product, required VoidCallback onTap})` — same public API as before, internals rebuilt. Consumed by Task 5 (`ProductListPage`).

- [ ] **Step 1: Write the failing tests**

Create `dtsretail_app/test/features/product/presentation/widgets/product_card_test.dart`:

```dart
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
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductCard(product: _product, onTap: () {}))));

    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('\$29.90'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductCard(product: _product, onTap: () => tapped = true))));

    await tester.tap(find.byType(ProductCard));
    expect(tapped, isTrue);
  });

  testWidgets('does not show a status badge for an active product', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductCard(product: _product, onTap: () {}))));
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

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductCard(product: discontinued, onTap: () {}))));
    expect(find.text('Discontinued'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/product/presentation/widgets/product_card_test.dart
```

Expected: FAIL — the current `ProductCard` doesn't take `isDiscontinued` on `Product` yet in a way that renders a status badge (it renders a plain `ListTile`, so `find.text('Acme')` and `find.text('Discontinued')` both fail).

- [ ] **Step 3: Implement the redesigned `ProductCard`**

Replace the full contents of `dtsretail_app/lib/features/product/presentation/widgets/product_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/product.dart';
import 'product_badge.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(child: ProductImage(imageUrl: product.imageUrl, heroTag: product.heroTag)),
                  Positioned(top: 6, left: 6, child: ProductBadge(product: product, kind: ProductBadgeKind.category)),
                  Positioned(top: 6, right: 6, child: ProductBadge(product: product, kind: ProductBadgeKind.stock)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.productTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (product.productBrand.isNotEmpty)
              Text(product.productBrand, style: const TextStyle(fontSize: 11, color: AppColors.neutral)),
            if (product.status != ProductStatus.active) ...[
              const SizedBox(height: 4),
              ProductBadge(product: product, kind: ProductBadgeKind.status),
            ],
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${product.priceWithGst.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text('cost \$${product.cost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: AppColors.neutral)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/product/presentation/widgets/product_card_test.dart
```

Expected: `00:0X +4: All tests passed!`

- [ ] **Step 5: Run the full suite**

```bash
flutter test
```

Expected: all tests pass — note `product_list_page_test.dart` still uses the OLD `ProductListPage` (Task 5 rewrites it), so it should still pass unchanged since `ProductCard`'s public API (`product`, `onTap`) didn't change.

- [ ] **Step 6: Commit**

```bash
git add lib/features/product/presentation/widgets/product_card.dart test/features/product/presentation/widgets/product_card_test.dart
git commit -m "Redesign ProductCard: image with badges, status chip, price/cost"
```

---

## Task 5: `ProductListPage` redesign — grid, search, sort, infinite scroll, pull-to-refresh

**Files:**
- Modify: `dtsretail_app/lib/features/product/presentation/pages/product_list_page.dart`
- Modify: `dtsretail_app/lib/features/product/presentation/providers/product_providers.dart` (remove the now-unused `ProductSearchQuery`/`productSearchProvider` — see Step 6; Task 3 deliberately left them in place since removing them earlier would have broken the still-unmodified page)
- Delete: `dtsretail_app/lib/features/product/presentation/widgets/recent_searches_list.dart` (folded inline as chips — see Step 5; it becomes dead code otherwise)
- Modify: `dtsretail_app/test/features/product/presentation/product_list_page_test.dart`

**Interfaces:**
- Consumes: `ProductListQuery`, `ProductListState`, `productListProvider` (Task 3), `ProductCard` (Task 4).
- Produces: Rebuilt `ProductListPage` (same public API: `const ProductListPage({super.key, this.initialSearch})`).

- [ ] **Step 1: Note on `recent_searches_list.dart`**

The current `RecentSearchesList` widget renders `ListTile` rows; the redesign renders chips inline within `product_list_page.dart` instead (small enough not to warrant its own file, and this avoids maintaining two divergent recent-search UIs). Step 3 removes the import and the file; there's no other consumer (`grep -rn "RecentSearchesList"` under `lib/` confirms `product_list_page.dart` is the only usage).

- [ ] **Step 2: Update the test file's fake repository and fixtures for pagination/sort support**

In `dtsretail_app/test/features/product/presentation/product_list_page_test.dart`, replace the full contents:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/api/api_exception.dart';
import 'package:dtsretail_app/core/services/barcode_scanner_service.dart';
import 'package:dtsretail_app/core/widgets/app_error_view.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/presentation/pages/product_list_page.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_providers.dart';

Product _testProduct({String code = '2007786553', double qtyOnHand = 10}) {
  return Product(
    companyId: 'BAS',
    productTypeCode: 'BOOK',
    productCode: code,
    productBarcode: code,
    productTitle: 'Test Product',
    productBrand: 'NATIO',
    isEnabled: true,
    isDiscontinued: false,
    priceWithGst: 29.9,
    priceWithoutGst: 27.94,
    cost: 13.08,
    uom: 'CPY',
    qtyOnHand: qtyOnHand,
  );
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.error, List<List<Product>>? pages}) : pages = pages ?? [[_testProduct()]];

  final ApiException? error;
  final List<List<Product>> pages;
  String? lastSearchString;
  String? lastSortBy;
  String? lastSortDirection;
  int callCount = 0;

  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    callCount++;
    lastSearchString = searchString;
    lastSortBy = sortBy;
    lastSortDirection = sortDirection;
    if (error != null) throw error!;
    final items = page < pages.length ? pages[page] : const <Product>[];
    return ProductSearchResult(items: items, totalElements: pages.expand((p) => p).length, totalPages: pages.length);
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

class _FakeBarcodeScannerService implements BarcodeScannerService {
  _FakeBarcodeScannerService(this.barcode);
  final String? barcode;

  @override
  Future<String?> scan(BuildContext context) async => barcode;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows search results after submitting a query', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Test Product'), findsOneWidget);
  });

  testWidgets('seeds the search from initialSearch without any typing', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage(initialSearch: '2007786553')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Product'), findsOneWidget);
    expect(repo.lastSearchString, '2007786553');
    expect(find.widgetWithText(TextField, '2007786553'), findsOneWidget);
  });

  testWidgets('scanning a barcode via the injected scanner service seeds a search', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
          barcodeScannerServiceProvider.overrideWithValue(_FakeBarcodeScannerService('2007786553')),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();

    expect(find.text('Test Product'), findsOneWidget);
    expect(repo.lastSearchString, '2007786553');
  });

  testWidgets('shows a friendly message instead of a raw exception on network failure', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository(error: const NetworkException('Unable to reach the server. Check your connection.'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
  });

  testWidgets('debounces as-you-type search and does not search before the timer elapses', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Test Product'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Test Product'), findsOneWidget);
  });

  testWidgets('changing the sort dropdown re-queries with the new sortBy/sortDirection', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.lastSortBy, 'productCode');

    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price Low-High').last);
    await tester.pumpAndSettle();

    expect(repo.lastSortBy, 'productPriceWgst');
    expect(repo.lastSortDirection, 'asc');
  });

  testWidgets('scrolling near the bottom loads the next page', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository(
      pages: [
        List.generate(20, (i) => _testProduct(code: 'P$i')),
        [_testProduct(code: 'P20')],
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final callsBeforeScroll = repo.callCount;
    await tester.drag(find.byType(GridView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(repo.callCount, greaterThan(callsBeforeScroll));
  });

  testWidgets('pull-to-refresh re-queries the same search', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final callsBeforeRefresh = repo.callCount;
    await tester.fling(find.byType(GridView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(repo.callCount, greaterThan(callsBeforeRefresh));
  });
}

AuthAuthenticated _authenticatedState() {
  return AuthAuthenticated(
    AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW'],
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    ),
  );
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(AuthState initial, Ref ref) : super(ref) {
    state = initial;
  }

  @override
  Future<void> restoreSession() async {}
}

class _ReadOnlyRef implements Ref {
  _ReadOnlyRef(this._container);
  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Ref member invoked on test stub: ${invocation.memberName}. Only read() is supported.');
  }
}
```

- [ ] **Step 3: Run it to verify the new tests fail**

```bash
flutter test test/features/product/presentation/product_list_page_test.dart
```

Expected: the 4 pre-existing-style tests still pass against the OLD page; the 3 new tests (debounce, sort, infinite scroll, pull-to-refresh — 4 new total) FAIL because the old page has no debounce, no sort dropdown, no `GridView`, no `RefreshIndicator`.

- [ ] **Step 4: Implement the redesigned `ProductListPage`**

Replace the full contents of `dtsretail_app/lib/features/product/presentation/pages/product_list_page.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../core/storage/recent_searches_storage.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/product_list_notifier.dart';
import '../widgets/product_card.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _SortOption {
  const _SortOption(this.label, this.sortBy, this.sortDirection);
  final String label;
  final String sortBy;
  final String sortDirection;
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _submittedQuery = '';
  int _searchKey = 0;
  String _sortBy = 'productCode';
  String _sortDirection = 'asc';
  Timer? _debounce;

  static const _searchKeyLabels = {0: 'Any', 1: 'Code', 3: 'Barcode', 4: 'Title'};
  static const _sortOptions = [
    _SortOption('Code A-Z', 'productCode', 'asc'),
    _SortOption('Title A-Z', 'productTitle', 'asc'),
    _SortOption('Title Z-A', 'productTitle', 'desc'),
    _SortOption('Price Low-High', 'productPriceWgst', 'asc'),
    _SortOption('Price High-Low', 'productPriceWgst', 'desc'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearch?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      _submittedQuery = initial;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_submittedQuery.isEmpty) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final companyId = _companyId();
      if (companyId != null) {
        ref.read(productListProvider(_query(companyId)).notifier).loadMore();
      }
    }
  }

  String? _companyId() {
    final authState = ref.read(authStateProvider);
    return authState is AuthAuthenticated ? authState.session.companyId : null;
  }

  ProductListQuery _query(String companyId) {
    return ProductListQuery(
      companyId: companyId,
      searchString: _submittedQuery,
      searchKey: _searchKey,
      sortBy: _sortBy,
      sortDirection: _sortDirection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final companyId = authState is AuthAuthenticated ? authState.session.companyId : null;

    return AppPageScaffold(
      currentPath: '/products',
      title: 'Product Catalog',
      actions: [IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanAndSearch(companyId))],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => _onSearchChanged(value, companyId),
              onSubmitted: (value) => _submitSearch(value, companyId),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: _searchKeyDropdown(companyId)),
                const SizedBox(width: 8),
                Expanded(child: _sortDropdown(companyId)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildResultsOrRecent(companyId)),
        ],
      ),
    );
  }

  // DropdownButtonFormField's `initialValue` only seeds the field's FIRST
  // build; visual updates thereafter flow through its own internal
  // FormFieldState via the `onChanged` callback below (which this widget
  // also uses to update `_searchKey`/`_sortBy`/`_sortDirection`), not through
  // rebuilding with a new `initialValue`. No extra sync code needed.
  Widget _searchKeyDropdown(String? companyId) {
    return DropdownButtonFormField<int>(
      initialValue: _searchKey,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: _searchKeyLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _searchKey = value);
        if (_submittedQuery.isNotEmpty) _submitSearch(_submittedQuery, companyId);
      },
    );
  }

  Widget _sortDropdown(String? companyId) {
    final currentIndex = _sortOptions.indexWhere((o) => o.sortBy == _sortBy && o.sortDirection == _sortDirection);
    return DropdownButtonFormField<int>(
      initialValue: currentIndex,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [for (var i = 0; i < _sortOptions.length; i++) DropdownMenuItem(value: i, child: Text(_sortOptions[i].label))],
      onChanged: (value) {
        if (value == null) return;
        final option = _sortOptions[value];
        setState(() {
          _sortBy = option.sortBy;
          _sortDirection = option.sortDirection;
        });
        if (_submittedQuery.isNotEmpty) _submitSearch(_submittedQuery, companyId);
      },
    );
  }

  Widget _buildResultsOrRecent(String? companyId) {
    if (companyId == null) return const SizedBox.shrink();

    if (_submittedQuery.isEmpty) {
      final recentAsync = ref.watch(recentSearchesStorageProvider);
      return recentAsync.when(
        data: (storage) => FutureBuilder<List<String>>(
          future: storage.read('product'),
          builder: (context, snapshot) {
            final terms = snapshot.data ?? const [];
            if (terms.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: terms
                    .map(
                      (term) => ActionChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: Text(term),
                        onPressed: () {
                          _searchController.text = term;
                          _submitSearch(term, companyId);
                        },
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }

    final query = _query(companyId);
    final state = ref.watch(productListProvider(query));

    if (state.error != null) {
      return AppErrorView(
        message: 'Unable to load products. Please try again.',
        onRetry: () => ref.read(productListProvider(query).notifier).refresh(),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return const _EmptyResults();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(productListProvider(query).notifier).refresh(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          final product = state.items[index];
          return ProductCard(
            product: product,
            onTap: () => context.push('/products/${product.companyId}/${product.productTypeCode}/${product.productCode}'),
          );
        },
      ),
    );
  }

  void _onSearchChanged(String value, String? companyId) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _submitSearch(value, companyId));
  }

  void _submitSearch(String value, String? companyId) {
    _debounce?.cancel();
    if (companyId == null) return;
    setState(() => _submittedQuery = value.trim());
    if (_submittedQuery.isNotEmpty) {
      ref.read(recentSearchesStorageProvider).whenData((storage) => storage.add('product', _submittedQuery));
    }
  }

  Future<void> _scanAndSearch(String? companyId) async {
    final scanner = ref.read(barcodeScannerServiceProvider);
    final barcode = await scanner.scan(context);
    if (barcode != null) {
      _searchController.text = barcode;
      _submitSearch(barcode, companyId);
    }
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.neutral.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('No products found.'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Delete the now-unused `recent_searches_list.dart`**

```bash
rm lib/features/product/presentation/widgets/recent_searches_list.dart
```

- [ ] **Step 6: Remove the now-unused `ProductSearchQuery`/`productSearchProvider`**

The rewritten `product_list_page.dart` from Step 4 no longer references these — they were the old single-page provider Task 3's `ProductListNotifier` replaces (kept alive until now specifically so the codebase kept compiling between Task 3 and this step). Replace the full contents of `dtsretail_app/lib/features/product/presentation/providers/product_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/product_remote_datasource.dart';
import '../../data/repository/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repository/product_repository.dart';
import '../../domain/usecases/get_product_detail_usecase.dart';
import '../../domain/usecases/search_products_usecase.dart';

final productRemoteDatasourceProvider = Provider((ref) => ProductRemoteDatasource(ref.watch(dioClientProvider)));

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(productRemoteDatasourceProvider));
});

final searchProductsUsecaseProvider = Provider((ref) => SearchProductsUsecase(ref.watch(productRepositoryProvider)));
final getProductDetailUsecaseProvider = Provider((ref) => GetProductDetailUsecase(ref.watch(productRepositoryProvider)));

final productDetailProvider = FutureProvider.family<Product, ({String companyId, String productTypeCode, String productCode})>(
  (ref, args) {
    return ref.watch(getProductDetailUsecaseProvider)(
      companyId: args.companyId,
      productTypeCode: args.productTypeCode,
      productCode: args.productCode,
    );
  },
);
```

- [ ] **Step 7: Run the test file to verify it passes**

```bash
flutter test test/features/product/presentation/product_list_page_test.dart
```

Expected: `00:0X +8: All tests passed!` (4 original-style + debounce + sort + infinite-scroll + pull-to-refresh).

- [ ] **Step 8: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass, `flutter analyze` reports no new issues (confirms `recent_searches_list.dart`'s removal and the `product_providers.dart` cleanup left no dangling imports or references).

- [ ] **Step 9: Manual visual check**

If a device/emulator is available, run `flutter run`, navigate to Product Catalog, and confirm: grid renders with placeholder icons where `prodImage` is empty (real image data depends on the connected backend's actual product records), category/stock badges show on cards, sort and search-key dropdowns work, scrolling near the bottom loads more, pull-to-refresh works. If not available, note that and rely on the widget-test coverage above (matches this project's own established precedent — Task 15 of the foundation plan and Task 3 of the login-redesign plan both accepted widget-test coverage as sufficient when a live emulator run wasn't possible in the environment).

- [ ] **Step 10: Commit**

```bash
git add lib/features/product/presentation/pages/product_list_page.dart lib/features/product/presentation/providers/product_providers.dart test/features/product/presentation/product_list_page_test.dart
git rm lib/features/product/presentation/widgets/recent_searches_list.dart
git commit -m "Redesign ProductListPage: grid, badges, debounced search, sort, infinite scroll, pull-to-refresh"
```

---

## Task 6: `ProductDetailPage` redesign

**Files:**
- Modify: `dtsretail_app/lib/features/product/presentation/pages/product_detail_page.dart`
- Test: `dtsretail_app/test/features/product/presentation/pages/product_detail_page_test.dart` (new)

**Interfaces:**
- Consumes: `ProductBadge`, `ProductImage` (Task 2), `Product.heroTag`, `Product.status` (Task 1), `productDetailProvider` (existing, unchanged).
- Produces: Rebuilt `ProductDetailPage` (same public API).

- [ ] **Step 1: Write the failing tests**

Create `dtsretail_app/test/features/product/presentation/pages/product_detail_page_test.dart`:

```dart
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
    await tester.pumpWidget(buildPage(_FakeProductRepository()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/product/presentation/pages/product_detail_page_test.dart
```

Expected: FAIL — the current page shows plain `Text('Brand: NATIO')` rows, not `find.text('NATIO')` alone, and has no badges.

- [ ] **Step 3: Implement the redesigned `ProductDetailPage`**

Replace the full contents of `dtsretail_app/lib/features/product/presentation/pages/product_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../widgets/product_badge.dart';
import '../widgets/product_image.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({
    super.key,
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
    final productAsync = ref.watch(productDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Detail')),
      body: productAsync.when(
        data: (product) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: ProductImage(imageUrl: product.imageUrl, heroTag: product.heroTag, borderRadius: 16, fallbackIconSize: 56),
            ),
            const SizedBox(height: 16),
            Text(product.productTitle, style: Theme.of(context).textTheme.titleLarge),
            if (product.productBrand.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(product.productBrand, style: const TextStyle(color: AppColors.neutral)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProductBadge(product: product, kind: ProductBadgeKind.category),
                ProductBadge(product: product, kind: ProductBadgeKind.stock),
                if (product.status != ProductStatus.active) ProductBadge(product: product, kind: ProductBadgeKind.status),
              ],
            ),
            const SizedBox(height: 20),
            _InfoCard(
              title: 'Details',
              rows: [('Code', product.productCode), ('Barcode', product.productBarcode), ('UOM', product.uom)],
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Pricing',
              rows: [
                ('Price (incl. GST)', '\$${product.priceWithGst.toStringAsFixed(2)}'),
                ('Price (excl. GST)', '\$${product.priceWithoutGst.toStringAsFixed(2)}'),
                ('Cost', '\$${product.cost.toStringAsFixed(2)}'),
                ('Qty on hand', product.qtyOnHand.toStringAsFixed(0)),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error is ApiException ? error.message : 'An unexpected error occurred.',
          onRetry: () => ref.invalidate(productDetailProvider(args)),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.neutral)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

`_InfoCard` reads `Theme.of(context)` from its own `build(BuildContext context)` — no need to thread the parent's context through the constructor; `Theme` is inherited, so a descendant widget's own build context resolves it identically.

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/product/presentation/pages/product_detail_page_test.dart
```

Expected: `00:0X +4: All tests passed!`

- [ ] **Step 5: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass, no new analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/product/presentation/pages/product_detail_page.dart test/features/product/presentation/pages/product_detail_page_test.dart
git commit -m "Redesign ProductDetailPage: hero image, badges, Details/Pricing cards"
```

---

## Task 7: Manual verification against the running app

**Files:** None (verification only).

- [ ] **Step 1: Run the full suite one more time**

```bash
flutter test
flutter analyze
```

Expected: all tests pass (by now roughly 60+ tests across the project), no analyzer issues.

- [ ] **Step 2: Run the app**

```bash
flutter run
```

(Or use an already-running emulator.)

- [ ] **Step 3: Visually verify the product list**

Navigate to Product Catalog. Check against `designs/appdesign.png`: 2-column grid, category/stock badges on each card (colors: green In Stock, amber Low Stock, red Out of Stock), status chip only on non-Active products, image placeholder icon where no `prodImage` exists on the connected backend's data. Type into search — confirm results update ~400ms after typing stops, and immediately on pressing "done". Change the search-key and sort dropdowns — confirm results re-query. Scroll to the bottom — confirm more items load with a small spinner. Pull down to refresh — confirm results reload.

- [ ] **Step 4: Visually verify the product detail page**

Tap a card — confirm a `Hero` shared-element transition from the card's image into the detail page's hero image. Check the Details and Pricing cards render correctly, no edit icon present, badges match the list page's badges for the same product.

- [ ] **Step 5: Verify image fallback**

If any product in the connected backend has no `prodImage` (or the app is tested against data where it's null), confirm the neutral icon placeholder renders instead of a broken-image icon or blank space, on both the grid card and the detail page.

No commit for this task — it's verification only, not a code change.
