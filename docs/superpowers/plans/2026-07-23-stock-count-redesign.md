# Stock Count Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a warehouse-picker bottom sheet that gates "New Stock Count" creation (with the last-used warehouse remembered), add real Status/Warehouse filters to the list, and redesign the list card and detail page to match the brand styling already shipped for Login and Product Catalog.

**Architecture:** Extends the existing `data / domain / presentation` layering — the repository chain gains a `warehouse` filter param (mirroring how Product's `sortBy` was added); a new `RememberedWarehouseStorage` mirrors the existing `RememberedUsernameStorage`; a new `WarehousePickerSheet` replaces the form's inline warehouse selector; `ProductDetailPage`'s private info-card widget is promoted to a shared `InfoSectionCard` now used by both Product and Stock Count detail pages.

**Tech Stack:** Flutter 3.44.6 / Dart ^3.8.1, Riverpod (`flutter_riverpod`), `shared_preferences` (already a dependency), `go_router` — no new packages.

## Global Constraints

- Real backend status lifecycle (confirmed against `StockCountServiceImpl.java`): `OPEN` → `APPROVED` → `POSTED`. No "Closed" state for Stock Count (that belongs to the separate Stock Pick module).
- Status color convention (new, `AppColors` values already exist from prior work): Open → `AppColors.primary`, Approved → `AppColors.accent`, Posted → `AppColors.neutral`.
- Variance coloring is **signed**, not "non-zero = danger": positive → `AppColors.primary`, negative → `AppColors.danger`, zero → `AppColors.neutral`. Confirmed real via `StockCountServiceImpl.java:211` (`varQty > 0 ? "IN" : "OUT"`).
- The warehouse picker is a **bottom sheet** (`showModalBottomSheet`), not a dialog.
- `StockCountFormPage`'s warehouse becomes **read-only** in both create and edit modes — no inline `WarehouseSelector` in the form anymore. `WarehouseSelector` itself is not deleted — it moves to being consumed by `WarehousePickerSheet` instead.
- Out of scope, do not add: the separate Stock Pick module, free-text search, client-controllable sort, Approve/Post UI, `dateUpdated` formatting, a searchable/filterable warehouse picker, icons on status chips, a header status-count summary.
- Existing widget/behavior compatibility: `StockCountFormPage`'s OPEN-status edit guard (blocks editing a non-OPEN count) is unchanged; its constructor gains only one new optional param (`whseCode`).
- All `flutter`/`dart` commands below assume the working directory is `dtsretail_app/` (the Flutter project root inside the worktree).

---

## Task 1: Data layer — `warehouse` filter param

**Files:**
- Modify: `dtsretail_app/lib/features/stock_count/domain/repository/stock_count_repository.dart`
- Modify: `dtsretail_app/lib/features/stock_count/data/repository/stock_count_repository_impl.dart`
- Modify: `dtsretail_app/lib/features/stock_count/data/datasource/remote/stock_count_remote_datasource.dart`
- Modify: `dtsretail_app/lib/features/stock_count/domain/usecases/search_stock_counts_usecase.dart`
- Modify: `dtsretail_app/lib/features/stock_count/presentation/providers/stock_count_providers.dart`
- Modify (compile-required, not a redesign): `dtsretail_app/test/features/stock_count/presentation/stock_count_list_page_test.dart`
- Modify (compile-required, not a redesign): `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart`
- Test: `dtsretail_app/test/features/stock_count/domain/usecases/search_stock_counts_usecase_test.dart` (new)

**Interfaces:**
- Produces: `StockCountRepository.search(...)` / `SearchStockCountsUsecase.call(...)` gain `String? warehouse` (nullable, no filter when absent). `StockCountSearchQuery` gains a `warehouse` field, included in `==`/`hashCode`.
- Consumes: nothing new from other tasks — this task is foundational, consumed by Task 6.

- [ ] **Step 1: Add `warehouse` to the repository interface**

In `dtsretail_app/lib/features/stock_count/domain/repository/stock_count_repository.dart`, replace the `search` method signature:

```dart
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page,
    int size,
  });
```

- [ ] **Step 2: Thread it through the impl, datasource, and usecase**

In `dtsretail_app/lib/features/stock_count/data/repository/stock_count_repository_impl.dart`, replace the `search` override:

```dart
  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async {
    final dto = await _remote.search(
      companyId: companyId,
      branchId: branchId,
      status: status,
      warehouse: warehouse,
      page: page,
      size: size,
    );
    return dto.toDomain();
  }
```

In `dtsretail_app/lib/features/stock_count/data/datasource/remote/stock_count_remote_datasource.dart`, replace the `search` method:

```dart
  Future<StockCountSearchResponseDto> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get('/inventory/stock-counts/search', queryParameters: {
        'companyId': companyId,
        'branchId': branchId,
        if (status != null) 'status': status,
        if (warehouse != null) 'warehouse': warehouse,
        'page': page,
        'size': size,
      });
      final body = response.data as Map<String, dynamic>;
      return StockCountSearchResponseDto.fromJson(body['data'] as Map<String, dynamic>);
    });
  }
```

In `dtsretail_app/lib/features/stock_count/domain/usecases/search_stock_counts_usecase.dart`, replace the `call` method:

```dart
  Future<StockCountSearchResult> call({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) {
    return _repository.search(companyId: companyId, branchId: branchId, status: status, warehouse: warehouse, page: page, size: size);
  }
```

- [ ] **Step 3: Add `warehouse` to `StockCountSearchQuery`**

In `dtsretail_app/lib/features/stock_count/presentation/providers/stock_count_providers.dart`, replace the `StockCountSearchQuery` class and `stockCountSearchProvider`:

```dart
class StockCountSearchQuery {
  const StockCountSearchQuery({required this.companyId, required this.branchId, this.status, this.warehouse});
  final String companyId;
  final String branchId;
  final String? status;
  final String? warehouse;

  @override
  bool operator ==(Object other) =>
      other is StockCountSearchQuery &&
      other.companyId == companyId &&
      other.branchId == branchId &&
      other.status == status &&
      other.warehouse == warehouse;

  @override
  int get hashCode => Object.hash(companyId, branchId, status, warehouse);
}

final stockCountSearchProvider = FutureProvider.family<StockCountSearchResult, StockCountSearchQuery>((ref, query) {
  return ref.watch(searchStockCountsUsecaseProvider)(
    companyId: query.companyId,
    branchId: query.branchId,
    status: query.status,
    warehouse: query.warehouse,
  );
});
```

- [ ] **Step 4: Fix the two `implements StockCountRepository` fakes' method signatures (compile-required)**

Both test files below have a `_FakeStockCountRepository` that `implements StockCountRepository` and must declare the new named parameter. No behavior change — just the signature.

In `dtsretail_app/test/features/stock_count/presentation/stock_count_list_page_test.dart`, update the fake's `search` override:

```dart
  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async {
    return const StockCountSearchResult(
      items: [
        StockCount(
          companyId: 'BAS',
          branchId: 'BAS1',
          stockcntId: 'SC0089',
          cntType: 'POSCNT',
          status: 'OPEN',
          stockcntDate: '2020-08-02',
          whseCode: 'BBPOS',
          totalItems: 1,
          totalCountQty: 45,
          totalVarQty: -2,
          dateUpdated: '2020-08-02T10:00:00',
          lines: [],
        ),
      ],
      totalElements: 1,
      totalPages: 1,
    );
  }
```

In `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart`, update the fake's `search` override (no other change in this file yet — its behavior-level rewrite happens in Task 5):

```dart
  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async {
    return const StockCountSearchResult(items: [], totalElements: 0, totalPages: 0);
  }
```

- [ ] **Step 5: Run the full suite to confirm the compile-fix is complete**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Write `search_stock_counts_usecase_test.dart` (new)**

Create `dtsretail_app/test/features/stock_count/domain/usecases/search_stock_counts_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/warehouse.dart';
import 'package:dtsretail_app/features/stock_count/domain/repository/stock_count_repository.dart';
import 'package:dtsretail_app/features/stock_count/domain/usecases/search_stock_counts_usecase.dart';

class _FakeStockCountRepository implements StockCountRepository {
  String? capturedStatus;
  String? capturedWarehouse;

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async {
    capturedStatus = status;
    capturedWarehouse = warehouse;
    return const StockCountSearchResult(items: [], totalElements: 0, totalPages: 0);
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async => const [];
}

void main() {
  test('SearchStockCountsUsecase defaults status/warehouse to null (no filter)', () async {
    final repo = _FakeStockCountRepository();
    final usecase = SearchStockCountsUsecase(repo);

    await usecase(companyId: 'BAS', branchId: 'BAS1');

    expect(repo.capturedStatus, isNull);
    expect(repo.capturedWarehouse, isNull);
  });

  test('SearchStockCountsUsecase forwards status and warehouse filters', () async {
    final repo = _FakeStockCountRepository();
    final usecase = SearchStockCountsUsecase(repo);

    await usecase(companyId: 'BAS', branchId: 'BAS1', status: 'OPEN', warehouse: 'BBPOS');

    expect(repo.capturedStatus, 'OPEN');
    expect(repo.capturedWarehouse, 'BBPOS');
  });
}
```

- [ ] **Step 7: Run it, then the full suite**

```bash
flutter test test/features/stock_count/domain/usecases/search_stock_counts_usecase_test.dart
flutter test
```

Expected: `00:0X +2: All tests passed!` then a fully green full suite.

- [ ] **Step 8: Commit**

```bash
git add lib/features/stock_count/domain/repository/stock_count_repository.dart lib/features/stock_count/data/repository/stock_count_repository_impl.dart lib/features/stock_count/data/datasource/remote/stock_count_remote_datasource.dart lib/features/stock_count/domain/usecases/search_stock_counts_usecase.dart lib/features/stock_count/presentation/providers/stock_count_providers.dart test/features/stock_count/presentation/stock_count_list_page_test.dart test/features/stock_count/presentation/stock_count_form_page_test.dart test/features/stock_count/domain/usecases/search_stock_counts_usecase_test.dart
git commit -m "Add warehouse filter param to stock count search chain"
```

---

## Task 2: `RememberedWarehouseStorage`

**Files:**
- Create: `dtsretail_app/lib/core/storage/remembered_warehouse_storage.dart`
- Test: `dtsretail_app/test/core/storage/remembered_warehouse_storage_test.dart` (new)

**Interfaces:**
- Produces: `RememberedWarehouseStorage(SharedPreferences prefs)` with `String? read()`, `Future<void> save(String warehouseCode)`; `final rememberedWarehouseStorageProvider = FutureProvider<RememberedWarehouseStorage>(...)`. Consumed by Task 4 (`WarehousePickerSheet`).

- [ ] **Step 1: Write the failing test**

Create `dtsretail_app/test/core/storage/remembered_warehouse_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/remembered_warehouse_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when nothing is stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedWarehouseStorage(prefs);

    expect(storage.read(), isNull);
  });

  test('save then read round-trips the warehouse code', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedWarehouseStorage(prefs);

    await storage.save('BBPOS');

    expect(storage.read(), 'BBPOS');
  });

  test('save overwrites a previously saved warehouse code', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedWarehouseStorage(prefs);

    await storage.save('BBPOS');
    await storage.save('BBPOS2');

    expect(storage.read(), 'BBPOS2');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/core/storage/remembered_warehouse_storage_test.dart
```

Expected: FAIL to compile — the class doesn't exist yet.

- [ ] **Step 3: Implement `RememberedWarehouseStorage`**

Create `dtsretail_app/lib/core/storage/remembered_warehouse_storage.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberedWarehouseStorage {
  RememberedWarehouseStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'remembered_warehouse_code';

  String? read() => _prefs.getString(_key);

  Future<void> save(String warehouseCode) => _prefs.setString(_key, warehouseCode);
}

final rememberedWarehouseStorageProvider = FutureProvider<RememberedWarehouseStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RememberedWarehouseStorage(prefs);
});
```

- [ ] **Step 4: Run it to verify it passes, then the full suite**

```bash
flutter test test/core/storage/remembered_warehouse_storage_test.dart
flutter test
```

Expected: `00:0X +3: All tests passed!` then a fully green full suite.

- [ ] **Step 5: Commit**

```bash
git add lib/core/storage/remembered_warehouse_storage.dart test/core/storage/remembered_warehouse_storage_test.dart
git commit -m "Add RememberedWarehouseStorage"
```

---

## Task 3: Shared widgets — `InfoSectionCard` (promoted) and `StockCountStatusChip`

**Files:**
- Create: `dtsretail_app/lib/shared/widgets/info_section_card.dart`
- Modify: `dtsretail_app/lib/features/product/presentation/pages/product_detail_page.dart` (use the shared widget instead of its private `_InfoCard`)
- Create: `dtsretail_app/lib/features/stock_count/presentation/widgets/stock_count_status_chip.dart`
- Test: `dtsretail_app/test/shared/widgets/info_section_card_test.dart` (new)
- Test: `dtsretail_app/test/features/stock_count/presentation/widgets/stock_count_status_chip_test.dart` (new)

**Interfaces:**
- Produces: `InfoSectionCard({required String title, required List<(String, String)> rows})`. `stockCountStatusColor(String status) -> Color` (top-level function) and `StockCountStatusChip({required String status})`. Both consumed by Tasks 6 and 7.

- [ ] **Step 1: Promote `_InfoCard` to `InfoSectionCard`**

Create `dtsretail_app/lib/shared/widgets/info_section_card.dart` — identical rendering to the existing private `_InfoCard` in `product_detail_page.dart`, just public and relocated:

```dart
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

class InfoSectionCard extends StatelessWidget {
  const InfoSectionCard({super.key, required this.title, required this.rows});

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

- [ ] **Step 2: Write its test**

Create `dtsretail_app/test/shared/widgets/info_section_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/shared/widgets/info_section_card.dart';

void main() {
  testWidgets('renders the title and each label/value row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoSectionCard(title: 'Details', rows: [('Code', 'ABC123'), ('UOM', 'EA')]),
        ),
      ),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('UOM'), findsOneWidget);
    expect(find.text('EA'), findsOneWidget);
  });

  testWidgets('renders just the title when rows is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InfoSectionCard(title: 'Empty', rows: []))),
    );

    expect(find.text('Empty'), findsOneWidget);
  });
}
```

```bash
flutter test test/shared/widgets/info_section_card_test.dart
```

Expected: `00:0X +2: All tests passed!`

- [ ] **Step 3: Switch `ProductDetailPage` to the shared widget**

In `dtsretail_app/lib/features/product/presentation/pages/product_detail_page.dart`:

Add the import:

```dart
import '../../../../shared/widgets/info_section_card.dart';
```

Replace both `_InfoCard(...)` call sites with `InfoSectionCard(...)` (same arguments, just the class name changes):

```dart
            InfoSectionCard(
              title: 'Details',
              rows: [('Code', product.productCode), ('Barcode', product.productBarcode), ('UOM', product.uom)],
            ),
            const SizedBox(height: 12),
            InfoSectionCard(
              title: 'Pricing',
              rows: [
                ('Price (incl. GST)', '\$${product.priceWithGst.toStringAsFixed(2)}'),
                ('Price (excl. GST)', '\$${product.priceWithoutGst.toStringAsFixed(2)}'),
                ('Cost', '\$${product.cost.toStringAsFixed(2)}'),
                ('Qty on hand', product.qtyOnHand.toStringAsFixed(0)),
              ],
            ),
```

Then delete the entire private `_InfoCard` class (the whole `class _InfoCard extends StatelessWidget { ... }` block) from the bottom of the file — it's now dead code, replaced by the shared widget.

- [ ] **Step 4: Run the product detail test to confirm it's unaffected**

```bash
flutter test test/features/product/presentation/pages/product_detail_page_test.dart
```

Expected: `00:0X +4: All tests passed!` — same rendered output, different source file, so this test (which only checks rendered text) is untouched and should pass unmodified.

- [ ] **Step 5: Write the failing `StockCountStatusChip` test**

Create `dtsretail_app/test/features/stock_count/presentation/widgets/stock_count_status_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/app/theme/app_theme.dart';
import 'package:dtsretail_app/features/stock_count/presentation/widgets/stock_count_status_chip.dart';

void main() {
  testWidgets('shows the OPEN label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'OPEN')));
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('shows the APPROVED label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'APPROVED')));
    expect(find.text('APPROVED'), findsOneWidget);
  });

  testWidgets('shows the POSTED label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'POSTED')));
    expect(find.text('POSTED'), findsOneWidget);
  });

  testWidgets('falls back gracefully for an unrecognized status', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StockCountStatusChip(status: 'UNKNOWN')));
    expect(find.text('UNKNOWN'), findsOneWidget);
  });

  test('stockCountStatusColor maps the three real lifecycle values', () {
    expect(stockCountStatusColor('OPEN'), AppColors.primary);
    expect(stockCountStatusColor('APPROVED'), AppColors.accent);
    expect(stockCountStatusColor('POSTED'), AppColors.neutral);
    expect(stockCountStatusColor('UNKNOWN'), AppColors.neutral);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

```bash
flutter test test/features/stock_count/presentation/widgets/stock_count_status_chip_test.dart
```

Expected: FAIL to compile — the file doesn't exist yet.

- [ ] **Step 7: Implement `StockCountStatusChip`**

Create `dtsretail_app/lib/features/stock_count/presentation/widgets/stock_count_status_chip.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// The real stock-count lifecycle is OPEN -> APPROVED -> POSTED (confirmed
/// against StockCountServiceImpl.java) — no "Closed" state; that belongs to
/// the separate Stock Pick module. Any other value falls back to neutral
/// rather than crashing, since `status` is a raw backend string, not an enum.
Color stockCountStatusColor(String status) {
  switch (status) {
    case 'OPEN':
      return AppColors.primary;
    case 'APPROVED':
      return AppColors.accent;
    case 'POSTED':
      return AppColors.neutral;
    default:
      return AppColors.neutral;
  }
}

class StockCountStatusChip extends StatelessWidget {
  const StockCountStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = stockCountStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
```

- [ ] **Step 8: Run it to verify it passes, then the full suite**

```bash
flutter test test/features/stock_count/presentation/widgets/stock_count_status_chip_test.dart
flutter test
```

Expected: `00:0X +5: All tests passed!` then a fully green full suite.

- [ ] **Step 9: Commit**

```bash
git add lib/shared/widgets/info_section_card.dart lib/features/product/presentation/pages/product_detail_page.dart lib/features/stock_count/presentation/widgets/stock_count_status_chip.dart test/shared/widgets/info_section_card_test.dart test/features/stock_count/presentation/widgets/stock_count_status_chip_test.dart
git commit -m "Add shared InfoSectionCard (promoted from ProductDetailPage) and StockCountStatusChip"
```

---

## Task 4: `WarehousePickerSheet` and router support

**Files:**
- Create: `dtsretail_app/lib/features/stock_count/presentation/widgets/warehouse_picker_sheet.dart`
- Modify: `dtsretail_app/lib/app/router.dart`
- Test: `dtsretail_app/test/features/stock_count/presentation/widgets/warehouse_picker_sheet_test.dart` (new)

**Interfaces:**
- Consumes: `warehousesProvider` (existing), `rememberedWarehouseStorageProvider` (Task 2), `WarehouseSelector` (existing, moves from being consumed by the form to being consumed here).
- Produces: `WarehousePickerSheet({required String companyId, required String branchId})`. On confirm, navigates to `/stock-counts/new?whseCode={code}` — the router now reads this into `StockCountFormPage.whseCode`. Consumed by Task 6 (`StockCountListPage`).

Note on a minor accepted timing edge case: the sheet's default-selection logic reads both `warehousesProvider` and `rememberedWarehouseStorageProvider` and only applies its `??=`-guarded default once, on whichever build first has warehouse data. If the remembered-warehouse read resolves *after* warehouses do, the sheet falls back to the branch-default instead of the remembered one for that one open. In practice `SharedPreferences.getInstance()` is near-instant (and by this point in the app other providers already backed by it have resolved), so this is a low-probability, low-impact race — not worth a synchronization mechanism, matching how a similar unawaited-prefill race was accepted during the login redesign.

- [ ] **Step 1: Add `whseCode` to the router's `/stock-counts/new` route**

In `dtsretail_app/lib/app/router.dart`, replace the `new` sub-route's builder:

```dart
          GoRoute(
            path: 'new',
            builder: (context, state) => StockCountFormPage(
              companyId: state.uri.queryParameters['companyId'],
              branchId: state.uri.queryParameters['branchId'],
              stockcntId: state.uri.queryParameters['stockcntId'],
              whseCode: state.uri.queryParameters['whseCode'],
            ),
          ),
```

(`StockCountFormPage` doesn't have a `whseCode` parameter yet — that's Task 5. This line will not compile until Task 5 lands. Steps 2 onward in this task build and test `WarehousePickerSheet` in isolation, which doesn't depend on this router line compiling — but the **full project** won't compile again until Task 5 adds the parameter. This is a deliberate two-task span, not an oversight: do not skip Task 5, and don't attempt to run the full suite between this step and Task 5's completion.)

- [ ] **Step 2: Write the failing `WarehousePickerSheet` tests**

Create `dtsretail_app/test/features/stock_count/presentation/widgets/warehouse_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/warehouse.dart';
import 'package:dtsretail_app/features/stock_count/domain/repository/stock_count_repository.dart';
import 'package:dtsretail_app/features/stock_count/presentation/providers/stock_count_providers.dart';
import 'package:dtsretail_app/features/stock_count/presentation/widgets/warehouse_picker_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeStockCountRepository implements StockCountRepository {
  _FakeStockCountRepository(this._warehouses);
  final List<Warehouse> _warehouses;

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async => const StockCountSearchResult(items: [], totalElements: 0, totalPages: 0);

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async => _warehouses;
}

const _warehouses = [
  Warehouse(code: 'BBPOS', description: 'Main Warehouse', branchCode: 'BAS1'),
  Warehouse(code: 'BBPOS2', description: 'Overflow Warehouse', branchCode: 'BAS2'),
];

Widget _buildHarness(StockCountRepository repo) {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => const WarehousePickerSheet(companyId: 'BAS', branchId: 'BAS1'),
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/stock-counts/new',
        builder: (context, state) => Scaffold(body: Text('Form for ${state.uri.queryParameters['whseCode']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [stockCountRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('pre-selects the branch-matching warehouse and enables Start Count', (tester) async {
    await tester.pumpWidget(_buildHarness(_FakeStockCountRepository(_warehouses)));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Select Warehouse'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start Count'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Cancel dismisses without navigating', (tester) async {
    await tester.pumpWidget(_buildHarness(_FakeStockCountRepository(_warehouses)));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Select Warehouse'), findsNothing);
    expect(find.textContaining('Form for'), findsNothing);
  });

  testWidgets('Start Count navigates to the form with the selected warehouse code', (tester) async {
    await tester.pumpWidget(_buildHarness(_FakeStockCountRepository(_warehouses)));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Count'));
    await tester.pumpAndSettle();

    expect(find.text('Form for BBPOS'), findsOneWidget);
  });

  testWidgets('pre-selects a remembered warehouse over the branch default', (tester) async {
    SharedPreferences.setMockInitialValues({'remembered_warehouse_code': 'BBPOS2'});
    await tester.pumpWidget(_buildHarness(_FakeStockCountRepository(_warehouses)));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Count'));
    await tester.pumpAndSettle();

    expect(find.text('Form for BBPOS2'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/features/stock_count/presentation/widgets/warehouse_picker_sheet_test.dart
```

Expected: FAIL to compile — `warehouse_picker_sheet.dart` doesn't exist yet.

- [ ] **Step 4: Implement `WarehousePickerSheet`**

Create `dtsretail_app/lib/features/stock_count/presentation/widgets/warehouse_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/remembered_warehouse_storage.dart';
import '../../domain/entities/warehouse.dart';
import '../providers/stock_count_providers.dart';
import 'warehouse_selector.dart';

class WarehousePickerSheet extends ConsumerStatefulWidget {
  const WarehousePickerSheet({super.key, required this.companyId, required this.branchId});

  final String companyId;
  final String branchId;

  @override
  ConsumerState<WarehousePickerSheet> createState() => _WarehousePickerSheetState();
}

class _WarehousePickerSheetState extends ConsumerState<WarehousePickerSheet> {
  Warehouse? _selected;

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehousesProvider(widget.companyId));
    final rememberedAsync = ref.watch(rememberedWarehouseStorageProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Select Warehouse', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 16),
          warehousesAsync.when(
            data: (warehouses) {
              _selected ??= _pickDefault(warehouses, rememberedAsync.asData?.value.read());
              return WarehouseSelector(
                warehouses: warehouses,
                selected: _selected,
                onChanged: (w) => setState(() => _selected = w),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (error, _) => Text('Could not load warehouses: $error'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selected == null ? null : _startCount,
                  child: const Text('Start Count'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Warehouse? _pickDefault(List<Warehouse> warehouses, String? rememberedCode) {
    if (warehouses.isEmpty) return null;
    if (rememberedCode != null) {
      for (final w in warehouses) {
        if (w.code == rememberedCode) return w;
      }
    }
    for (final w in warehouses) {
      if (w.branchCode == widget.branchId) return w;
    }
    return warehouses.first;
  }

  Future<void> _startCount() async {
    final selected = _selected!;
    final storage = await ref.read(rememberedWarehouseStorageProvider.future);
    await storage.save(selected.code);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    navigator.pop();
    router.push('/stock-counts/new?whseCode=${selected.code}');
  }
}
```

Note: `_startCount` captures `Navigator.of(context)` and `GoRouter.of(context)` *before* popping the sheet, then uses those captured references afterward — `context` itself becomes invalid the instant the sheet is popped, so any `context`-dependent lookup must happen first.

- [ ] **Step 5: Run it to verify it passes**

```bash
flutter test test/features/stock_count/presentation/widgets/warehouse_picker_sheet_test.dart
```

Expected: `00:0X +4: All tests passed!`

- [ ] **Step 6: Commit**

Note: the full suite is **not** run here — `router.dart`'s reference to `StockCountFormPage(..., whseCode: ...)` won't compile until Task 5 adds that parameter. Commit only the files this task actually owns.

```bash
git add lib/features/stock_count/presentation/widgets/warehouse_picker_sheet.dart lib/app/router.dart test/features/stock_count/presentation/widgets/warehouse_picker_sheet_test.dart
git commit -m "Add WarehousePickerSheet and whseCode route support"
```

---

## Task 5: `StockCountFormPage` changes

**Files:**
- Modify: `dtsretail_app/lib/features/stock_count/presentation/pages/stock_count_form_page.dart`
- Modify: `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart`

**Interfaces:**
- Consumes: the `whseCode` route param Task 4 already wired into the router.
- Produces: `StockCountFormPage` gains an optional `whseCode` constructor parameter (completing the compile Task 4 left pending); no more inline `WarehouseSelector`.

- [ ] **Step 1: Write the failing/updated tests**

Replace the full contents of `dtsretail_app/test/features/stock_count/presentation/stock_count_form_page_test.dart` (the `_FakeStockCountRepository`'s `search` signature already has `warehouse` from Task 1 — keep it as-is; everything below replaces the `main()` block and its two tests that concerned the old inline selector):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/services/barcode_scanner_service.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_providers.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/warehouse.dart';
import 'package:dtsretail_app/features/stock_count/domain/repository/stock_count_repository.dart';
import 'package:dtsretail_app/features/stock_count/presentation/pages/stock_count_form_page.dart';
import 'package:dtsretail_app/features/stock_count/presentation/providers/stock_count_providers.dart';

/// Fake repository whose `getDetail` responses are keyed by `stockcntId`, so
/// individual tests can point at an OPEN or a non-OPEN fixture, and whose
/// `update`/`create` calls are recorded for assertions.
class _FakeStockCountRepository implements StockCountRepository {
  _FakeStockCountRepository(this._byId);

  final Map<String, StockCount> _byId;
  final List<Map<String, Object?>> updateCalls = [];
  final List<Map<String, Object?>> createCalls = [];

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async {
    return const StockCountSearchResult(items: [], totalElements: 0, totalPages: 0);
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) async {
    final found = _byId[stockcntId];
    if (found == null) throw StateError('No fixture for $stockcntId');
    return found;
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) async {
    createCalls.add({
      'companyId': companyId,
      'branchId': branchId,
      'cntType': cntType,
      'whseCode': whseCode,
      'lines': lines,
      'userId': userId,
    });
    return StockCount(
      companyId: companyId,
      branchId: branchId,
      stockcntId: 'SC_NEW',
      cntType: cntType,
      status: 'OPEN',
      stockcntDate: '2026-07-20',
      whseCode: whseCode,
      totalItems: lines.length,
      totalCountQty: 0,
      totalVarQty: 0,
      dateUpdated: '2026-07-20T00:00:00',
      lines: lines,
    );
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) async {
    updateCalls.add({
      'companyId': companyId,
      'branchId': branchId,
      'stockcntId': stockcntId,
      'cntType': cntType,
      'whseCode': whseCode,
      'lines': lines,
      'userId': userId,
    });
    return StockCount(
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId,
      cntType: cntType,
      status: 'OPEN',
      stockcntDate: '2026-07-20',
      whseCode: whseCode,
      totalItems: lines.length,
      totalCountQty: 0,
      totalVarQty: 0,
      dateUpdated: '2026-07-20T00:00:00',
      lines: lines,
    );
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async {
    return const [
      Warehouse(code: 'BBPOS', description: 'Main Warehouse', branchCode: 'BAS1'),
      Warehouse(code: 'BBPOS2', description: 'Overflow Warehouse', branchCode: 'BAS2'),
    ];
  }
}

/// Fake [BarcodeScannerService] that returns a fixed barcode instead of
/// pushing the real (untestable, camera-backed) scanner UI.
class _FakeBarcodeScannerService implements BarcodeScannerService {
  _FakeBarcodeScannerService(this.barcode);

  final String barcode;

  @override
  Future<String?> scan(BuildContext context) async => barcode;
}

/// Fake [ProductRepository] whose `search` always resolves to the same
/// single product, regardless of the search string passed in — enough to
/// simulate "scanning the same barcode" resolving to the same product twice.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._product);

  final Product _product;

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

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) async {
    return _product;
  }
}

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

const _existingLine = StockCountLine(
  productCode: 'P001',
  productTypeCode: 'BOOK',
  productTitle: 'Existing Product',
  priceWithGst: 10,
  cost: 5,
  countQty: 3,
);

const _openStockCount = StockCount(
  companyId: 'BAS',
  branchId: 'BAS1',
  stockcntId: 'SC001',
  cntType: 'CNT',
  status: 'OPEN',
  stockcntDate: '2020-08-02',
  whseCode: 'BBPOS',
  totalItems: 1,
  totalCountQty: 3,
  totalVarQty: 0,
  dateUpdated: '2020-08-02T10:00:00',
  lines: [_existingLine],
);

const _postedStockCount = StockCount(
  companyId: 'BAS',
  branchId: 'BAS1',
  stockcntId: 'SC002',
  cntType: 'CNT',
  status: 'POSTED',
  stockcntDate: '2020-08-02',
  whseCode: 'BBPOS',
  totalItems: 1,
  totalCountQty: 3,
  totalVarQty: 0,
  dateUpdated: '2020-08-02T10:00:00',
  lines: [_existingLine],
);

void main() {
  group('StockCountFormPage', () {
    testWidgets('create mode without a whseCode shows a defensive error and no form', (tester) async {
      final fakeRepo = _FakeStockCountRepository({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockCountRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
          ],
          child: const MaterialApp(home: StockCountFormPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No warehouse was selected. Please start again from Stock Counts.'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(fakeRepo.createCalls, isEmpty);
    });

    testWidgets('create mode with a whseCode shows the warehouse read-only and blocks submission with no lines', (tester) async {
      final fakeRepo = _FakeStockCountRepository({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockCountRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
          ],
          child: const MaterialApp(home: StockCountFormPage(whseCode: 'BBPOS')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Stock Count'), findsOneWidget);
      expect(find.textContaining('BBPOS · Main Warehouse'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Add at least one line to save this count.'), findsOneWidget);
      expect(fakeRepo.createCalls, isEmpty);
    });

    testWidgets('edit mode loads an OPEN count and submits an update', (tester) async {
      final fakeRepo = _FakeStockCountRepository({'SC001': _openStockCount});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockCountRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StockCountFormPage(companyId: 'BAS', branchId: 'BAS1', stockcntId: 'SC001'),
                      ),
                    ),
                    child: const Text('Open Form'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Existing line loaded from the freshly-fetched detail; warehouse now read-only.
      expect(find.text('Existing Product'), findsOneWidget);
      expect(find.text('Edit Stock Count'), findsOneWidget);
      expect(find.textContaining('BBPOS · Main Warehouse'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeRepo.updateCalls, hasLength(1));
      expect(fakeRepo.updateCalls.single['stockcntId'], 'SC001');
      expect(fakeRepo.updateCalls.single['whseCode'], 'BBPOS');
      // Successful submit pops back to the launching screen.
      expect(find.text('Open Form'), findsOneWidget);
    });

    testWidgets('edit mode blocks editing a count that is no longer OPEN', (tester) async {
      final fakeRepo = _FakeStockCountRepository({'SC002': _postedStockCount});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockCountRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
          ],
          child: const MaterialApp(
            home: StockCountFormPage(companyId: 'BAS', branchId: 'BAS1', stockcntId: 'SC002'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This count has already been POSTED and can no longer be edited.'),
        findsOneWidget,
      );
      // No form controls or Save button are rendered while blocked.
      expect(find.text('Save'), findsNothing);
      expect(find.text('Scan barcode to add line'), findsNothing);
      expect(fakeRepo.updateCalls, isEmpty);
    });

    testWidgets('scanning the same product twice merges into one line instead of duplicating it', (tester) async {
      final fakeRepo = _FakeStockCountRepository({});
      final fakeProductRepo = _FakeProductRepository(_scannedProduct);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockCountRepositoryProvider.overrideWithValue(fakeRepo),
            productRepositoryProvider.overrideWithValue(fakeProductRepo),
            barcodeScannerServiceProvider.overrideWithValue(_FakeBarcodeScannerService('1234567890')),
            authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
          ],
          child: const MaterialApp(home: StockCountFormPage(whseCode: 'BBPOS')),
        ),
      );
      await tester.pumpAndSettle();

      // First scan adds a new line with qty 1.
      await tester.tap(find.text('Scan barcode to add line'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Scanned Product'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);

      // Second scan of the same barcode/product must merge into the existing
      // line (qty -> 2) rather than adding a second ListTile with the same
      // ValueKey (productTypeCode_productCode), which would otherwise throw
      // a duplicate GlobalKey/duplicate-key FlutterError during reconciliation.
      await tester.tap(find.text('Scan barcode to add line'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Scanned Product'), findsOneWidget);
      expect(find.text('2.0'), findsOneWidget);
    });
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
      features: const ['STOCK_COUNT'],
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    ),
  );
}

/// Test-only [AuthStateNotifier] that pins [state] to a fixed value and never
/// performs the real, I/O-bound session restoration. Mirrors the pattern in
/// `test/features/stock_count/presentation/stock_count_list_page_test.dart`.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(AuthState initial, Ref ref) : super(ref) {
    state = initial;
  }

  @override
  Future<void> restoreSession() async {
    // No-op: prevents the real (unmocked) SecureTokenStorage read that the
    // base constructor would otherwise trigger.
  }
}

/// Minimal [Ref] stub that forwards only [read] to a real [ProviderContainer]
/// and fails loudly for anything else, rather than silently returning null
/// for unhandled members (as a `noSuchMethod`-catch-all stub would).
class _ReadOnlyRef implements Ref {
  _ReadOnlyRef(this._container);

  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected Ref member invoked on test stub: ${invocation.memberName}. '
      'Only read() is supported.',
    );
  }
}
```

- [ ] **Step 2: Run it to verify the new/changed tests fail**

```bash
flutter test test/features/stock_count/presentation/stock_count_form_page_test.dart
```

Expected: FAIL — `StockCountFormPage` doesn't accept a `whseCode` parameter yet, and still renders the old inline `WarehouseSelector` / old validation message.

- [ ] **Step 3: Implement the `StockCountFormPage` changes**

Replace the full contents of `dtsretail_app/lib/features/stock_count/presentation/pages/stock_count_form_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/domain/entities/auth_session.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../product/presentation/providers/product_providers.dart';
import '../../domain/entities/stock_count_line.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/barcode_scan_line_entry.dart';

class StockCountFormPage extends ConsumerStatefulWidget {
  const StockCountFormPage({super.key, this.companyId, this.branchId, this.stockcntId, this.whseCode});

  final String? companyId;
  final String? branchId;
  final String? stockcntId;

  /// The warehouse code for a NEW count, supplied by [WarehousePickerSheet]
  /// via the route's query parameter. Ignored when editing — an existing
  /// count's warehouse comes from the loaded record instead. Read-only in
  /// both cases; see [_warehouseCode].
  final String? whseCode;

  bool get isEditing => stockcntId != null;

  @override
  ConsumerState<StockCountFormPage> createState() => _StockCountFormPageState();
}

class _StockCountFormPageState extends ConsumerState<StockCountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final List<StockCountLine> _lines = [];
  bool _isSaving = false;
  String? _errorMessage;

  // --- Editing-only state -------------------------------------------------
  //
  // The backend has no concurrency control on stock-count updates and always
  // forces the count's status back to OPEN on every update (see
  // UpdateStockCountUsecase / stock_count_mapper.dart from Task 11). Since
  // there is no server-side guard, this form is the only thing standing
  // between the user and silently corrupting a count that is no longer OPEN
  // (e.g. already CLOSED or POSTED). We therefore:
  //   1. Fetch the count's status directly from the usecase (bypassing
  //      stockCountDetailProvider's cache) when the form loads, so we never
  //      act on a stale value the detail page happened to have cached.
  //   2. Block editing entirely (no form, no Save) if it is not OPEN.
  //   3. Re-check immediately before submitting, to narrow (not eliminate —
  //      that needs a backend fix, out of scope for v1) the window in which
  //      another user could have closed/posted the count while this form
  //      was open.
  bool _loadingExisting = false;
  bool _blockedNotOpen = false;
  String? _existingStatus;
  String? _existingWhseCode;
  String? _loadErrorMessage;

  /// The warehouse code that applies to this form: the existing record's
  /// warehouse when editing, otherwise the code the picker sheet supplied.
  String? get _warehouseCode => widget.isEditing ? _existingWhseCode : widget.whseCode;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingExisting = true;
      Future.microtask(_loadExisting);
    }
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loadingExisting = true;
      _loadErrorMessage = null;
    });
    try {
      final usecase = ref.read(getStockCountDetailUsecaseProvider);
      final existing = await usecase(
        companyId: widget.companyId!,
        branchId: widget.branchId!,
        stockcntId: widget.stockcntId!,
      );
      if (!mounted) return;

      if (!existing.isOpen) {
        setState(() {
          _blockedNotOpen = true;
          _existingStatus = existing.status;
          _loadingExisting = false;
        });
        return;
      }

      setState(() {
        _lines
          ..clear()
          ..addAll(existing.lines);
        _existingStatus = existing.status;
        _existingWhseCode = existing.whseCode;
        _loadingExisting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadErrorMessage = 'Could not load stock count: $error';
        _loadingExisting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    if (widget.isEditing && _loadingExisting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Stock Count')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isEditing && _loadErrorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Stock Count')),
        body: AppErrorView(message: _loadErrorMessage!, onRetry: _loadExisting),
      );
    }

    if (widget.isEditing && _blockedNotOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Stock Count')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'This count has already been ${_existingStatus ?? 'closed'} and can no longer be edited.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!widget.isEditing && widget.whseCode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Stock Count')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warehouse_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No warehouse was selected. Please start again from Stock Counts.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );
    }

    final warehousesAsync = ref.watch(warehousesProvider(session.companyId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Stock Count' : 'New Stock Count')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            warehousesAsync.when(
              data: (warehouses) {
                final code = _warehouseCode;
                final match = warehouses.where((w) => w.code == code);
                final label = match.isNotEmpty ? '${match.first.code} · ${match.first.description}' : (code ?? '');
                return Text('Warehouse: $label', style: Theme.of(context).textTheme.titleMedium);
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load warehouse info: $error'),
            ),
            const SizedBox(height: 16),
            BarcodeScanLineEntry(
              lines: _lines,
              onScanPressed: () => _scanAndAddLine(session.companyId),
              onQtyChanged: (index, qty) => setState(() {
                final line = _lines[index];
                _lines[index] = StockCountLine(
                  productCode: line.productCode,
                  productTypeCode: line.productTypeCode,
                  productTitle: line.productTitle,
                  priceWithGst: line.priceWithGst,
                  cost: line.cost,
                  countQty: qty,
                );
              }),
              onRemove: (index) => setState(() => _lines.removeAt(index)),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : () => _submit(session),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndAddLine(String companyId) async {
    final scanner = ref.read(barcodeScannerServiceProvider);
    final barcode = await scanner.scan(context);
    if (barcode == null) return;

    try {
      final result = await ref.read(searchProductsUsecaseProvider)(
        companyId: companyId,
        searchString: barcode,
        searchKey: 3,
        size: 1,
      );
      if (result.items.isEmpty) {
        setState(() => _errorMessage = 'No product found for barcode $barcode');
        return;
      }

      final product = result.items.first;
      setState(() {
        _errorMessage = null;
        final existingIndex = _lines.indexWhere(
          (line) => line.productTypeCode == product.productTypeCode && line.productCode == product.productCode,
        );
        if (existingIndex != -1) {
          final existing = _lines[existingIndex];
          _lines[existingIndex] = StockCountLine(
            productCode: existing.productCode,
            productTypeCode: existing.productTypeCode,
            productTitle: existing.productTitle,
            priceWithGst: existing.priceWithGst,
            cost: existing.cost,
            countQty: existing.countQty + 1,
          );
        } else {
          _lines.add(StockCountLine(
            productCode: product.productCode,
            productTypeCode: product.productTypeCode,
            productTitle: product.productTitle,
            priceWithGst: product.priceWithGst,
            cost: product.cost,
            countQty: 1,
          ));
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to look up product: $error');
    }
  }

  Future<void> _submit(AuthSession session) async {
    final formValid = _formKey.currentState?.validate() ?? true;
    if (!formValid) return;

    if (_lines.isEmpty) {
      setState(() => _errorMessage = 'Add at least one line to save this count.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEditing) {
        final usecase = ref.read(getStockCountDetailUsecaseProvider);
        final current = await usecase(
          companyId: session.companyId,
          branchId: session.branchId,
          stockcntId: widget.stockcntId!,
        );
        if (!current.isOpen) {
          if (!mounted) return;
          setState(() {
            _blockedNotOpen = true;
            _existingStatus = current.status;
          });
          return;
        }

        await ref.read(updateStockCountUsecaseProvider)(
          companyId: session.companyId,
          branchId: session.branchId,
          stockcntId: widget.stockcntId!,
          cntType: 'CNT',
          whseCode: _warehouseCode!,
          lines: _lines,
          userId: session.loginId,
        );
      } else {
        await ref.read(createStockCountUsecaseProvider)(
          companyId: session.companyId,
          branchId: session.branchId,
          cntType: 'CNT',
          whseCode: _warehouseCode!,
          lines: _lines,
          userId: session.loginId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = 'Failed to save: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/stock_count/presentation/stock_count_form_page_test.dart
```

Expected: `00:0X +5: All tests passed!`

- [ ] **Step 5: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass (this is the point where `router.dart`'s reference to `whseCode` from Task 4 finally compiles, since `StockCountFormPage` now accepts it), `flutter analyze` clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/stock_count/presentation/pages/stock_count_form_page.dart test/features/stock_count/presentation/stock_count_form_page_test.dart
git commit -m "Remove inline warehouse selector from StockCountFormPage; warehouse now read-only, supplied by the picker sheet or the existing record"
```

---

## Task 6: `StockCountCard` and `StockCountListPage` redesign

**Files:**
- Modify: `dtsretail_app/lib/features/stock_count/presentation/widgets/stock_count_card.dart`
- Modify: `dtsretail_app/lib/features/stock_count/presentation/pages/stock_count_list_page.dart`
- Modify: `dtsretail_app/test/features/stock_count/presentation/stock_count_list_page_test.dart`
- Test: `dtsretail_app/test/features/stock_count/presentation/widgets/stock_count_card_test.dart` (new)

**Interfaces:**
- Consumes: `StockCountStatusChip`/`stockCountStatusColor` (Task 3), `WarehousePickerSheet` (Task 4), `warehouse` filter (Task 1).
- Produces: Rebuilt `StockCountCard` (same public API), rebuilt `StockCountListPage` (same public API, now `ConsumerStatefulWidget` instead of `ConsumerWidget` to hold filter state).

- [ ] **Step 1: Write the failing `StockCountCard` test**

Create `dtsretail_app/test/features/stock_count/presentation/widgets/stock_count_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/presentation/widgets/stock_count_card.dart';

StockCount _stockCount({String status = 'OPEN', double totalVarQty = 0}) {
  return StockCount(
    companyId: 'BAS',
    branchId: 'BAS1',
    stockcntId: 'SC0089',
    cntType: 'CNT',
    status: status,
    stockcntDate: '2020-08-02',
    whseCode: 'BBPOS',
    totalItems: 3,
    totalCountQty: 45,
    totalVarQty: totalVarQty,
    dateUpdated: '2020-08-02T10:00:00',
    lines: const [],
  );
}

void main() {
  testWidgets('shows the stock count id, status, warehouse, and item count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StockCountCard(stockCount: _stockCount(), onTap: () {}))),
    );

    expect(find.text('SC0089'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.textContaining('BBPOS'), findsOneWidget);
    expect(find.textContaining('3 items'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StockCountCard(stockCount: _stockCount(), onTap: () => tapped = true))),
    );

    await tester.tap(find.byType(StockCountCard));
    expect(tapped, isTrue);
  });

  testWidgets('shows the variance figure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StockCountCard(stockCount: _stockCount(totalVarQty: -2), onTap: () {}))),
    );

    expect(find.text('-2.0'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/stock_count/presentation/widgets/stock_count_card_test.dart
```

Expected: FAIL — the current card renders a plain `ListTile` with a `Text('${whseCode} · ${status} · ${totalItems} items')` combined subtitle, not the separated structure these assertions expect.

- [ ] **Step 3: Implement the redesigned `StockCountCard`**

Replace the full contents of `dtsretail_app/lib/features/stock_count/presentation/widgets/stock_count_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/stock_count.dart';
import 'stock_count_status_chip.dart';

class StockCountCard extends StatelessWidget {
  const StockCountCard({super.key, required this.stockCount, required this.onTap});

  final StockCount stockCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final variance = stockCount.totalVarQty;
    final varianceColor = variance > 0
        ? AppColors.primary
        : (variance < 0 ? AppColors.danger : AppColors.neutral);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(stockCount.stockcntId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 8),
                      StockCountStatusChip(status: stockCount.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stockCount.whseCode} · ${stockCount.totalItems} items',
                    style: const TextStyle(color: AppColors.neutral, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              variance.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.w700, color: varianceColor, fontSize: 14),
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
flutter test test/features/stock_count/presentation/widgets/stock_count_card_test.dart
```

Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Update the list page test**

Replace the full contents of `dtsretail_app/test/features/stock_count/presentation/stock_count_list_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/warehouse.dart';
import 'package:dtsretail_app/features/stock_count/domain/repository/stock_count_repository.dart';
import 'package:dtsretail_app/features/stock_count/presentation/pages/stock_count_list_page.dart';
import 'package:dtsretail_app/features/stock_count/presentation/providers/stock_count_providers.dart';

const _warehouses = [
  Warehouse(code: 'BBPOS', description: 'Main Warehouse', branchCode: 'BAS1'),
  Warehouse(code: 'BBPOS2', description: 'Overflow Warehouse', branchCode: 'BAS2'),
];

class _FakeStockCountRepository implements StockCountRepository {
  _FakeStockCountRepository({this.items = const []});

  final List<StockCount> items;
  String? lastStatus;
  String? lastWarehouse;
  int searchCallCount = 0;

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) async {
    searchCallCount++;
    lastStatus = status;
    lastWarehouse = warehouse;
    return StockCountSearchResult(items: items, totalElements: items.length, totalPages: 1);
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async => _warehouses;
}

const _sampleCount = StockCount(
  companyId: 'BAS',
  branchId: 'BAS1',
  stockcntId: 'SC0089',
  cntType: 'POSCNT',
  status: 'OPEN',
  stockcntDate: '2020-08-02',
  whseCode: 'BBPOS',
  totalItems: 1,
  totalCountQty: 45,
  totalVarQty: -2,
  dateUpdated: '2020-08-02T10:00:00',
  lines: [],
);

void main() {
  testWidgets('shows stock count results for the authenticated session', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(_FakeStockCountRepository(items: const [_sampleCount])),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SC0089'), findsOneWidget);
  });

  testWidgets('shows an empty state with a working Create Stock Count button', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(_FakeStockCountRepository()),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No stock counts found.'), findsOneWidget);
    expect(find.text('Create Stock Count'), findsOneWidget);

    await tester.tap(find.text('Create Stock Count'));
    await tester.pumpAndSettle();

    expect(find.text('Select Warehouse'), findsOneWidget);
  });

  testWidgets('the + action opens the warehouse picker sheet', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(_FakeStockCountRepository(items: const [_sampleCount])),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Select Warehouse'), findsOneWidget);
  });

  testWidgets('changing the status filter re-queries with the selected status', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeStockCountRepository(items: const [_sampleCount]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.lastStatus, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();

    expect(repo.lastStatus, 'OPEN');
  });

  testWidgets('changing the warehouse filter re-queries with the selected warehouse', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeStockCountRepository(items: const [_sampleCount]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.lastWarehouse, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BBPOS2').last);
    await tester.pumpAndSettle();

    expect(repo.lastWarehouse, 'BBPOS2');
  });

  testWidgets('pull-to-refresh re-queries', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakeStockCountRepository(items: const [_sampleCount]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container))),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();
    final callsBeforeRefresh = repo.searchCallCount;

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(repo.searchCallCount, greaterThan(callsBeforeRefresh));
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
      features: const ['STOCK_COUNT'],
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    ),
  );
}

/// Test-only [AuthStateNotifier] that pins [state] to a fixed value and never
/// performs the real, I/O-bound session restoration. Mirrors the pattern in
/// `test/features/product/presentation/product_list_page_test.dart`.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(AuthState initial, Ref ref) : super(ref) {
    state = initial;
  }

  @override
  Future<void> restoreSession() async {
    // No-op: prevents the real (unmocked) SecureTokenStorage read that the
    // base constructor would otherwise trigger.
  }
}

/// Minimal [Ref] stub that forwards only [read] to a real [ProviderContainer]
/// and fails loudly for anything else, rather than silently returning null
/// for unhandled members (as a `noSuchMethod`-catch-all stub would).
class _ReadOnlyRef implements Ref {
  _ReadOnlyRef(this._container);

  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected Ref member invoked on test stub: ${invocation.memberName}. '
      'Only read() is supported.',
    );
  }
}
```

- [ ] **Step 6: Run it to verify it fails**

```bash
flutter test test/features/stock_count/presentation/stock_count_list_page_test.dart
```

Expected: FAIL — the current list page has no filter dropdowns, no empty-state button, no pull-to-refresh, and the `+` icon navigates directly rather than opening a sheet.

- [ ] **Step 7: Implement the redesigned `StockCountListPage`**

Replace the full contents of `dtsretail_app/lib/features/stock_count/presentation/pages/stock_count_list_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/domain/entities/auth_session.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/warehouse.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/stock_count_card.dart';
import '../widgets/warehouse_picker_sheet.dart';

class StockCountListPage extends ConsumerStatefulWidget {
  const StockCountListPage({super.key});

  @override
  ConsumerState<StockCountListPage> createState() => _StockCountListPageState();
}

class _StockCountListPageState extends ConsumerState<StockCountListPage> {
  String? _status;
  String? _warehouse;

  static const _statusLabels = {null: 'All', 'OPEN': 'Open', 'APPROVED': 'Approved', 'POSTED': 'Posted'};

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    final query = StockCountSearchQuery(
      companyId: session.companyId,
      branchId: session.branchId,
      status: _status,
      warehouse: _warehouse,
    );
    final resultAsync = ref.watch(stockCountSearchProvider(query));
    final warehousesAsync = ref.watch(warehousesProvider(session.companyId));

    return AppPageScaffold(
      currentPath: '/stock-counts',
      title: 'Stock Counts',
      actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _openWarehousePicker(session))],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: _statusDropdown()),
                const SizedBox(width: 8),
                Expanded(child: _warehouseDropdown(warehousesAsync)),
              ],
            ),
          ),
          Expanded(
            child: resultAsync.when(
              data: (result) {
                if (result.items.isEmpty) {
                  return _EmptyResults(onCreate: () => _openWarehousePicker(session));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(stockCountSearchProvider(query).future),
                  child: ListView.builder(
                    itemCount: result.items.length,
                    itemBuilder: (context, index) {
                      final stockCount = result.items[index];
                      return StockCountCard(
                        stockCount: stockCount,
                        onTap: () =>
                            context.push('/stock-counts/${stockCount.companyId}/${stockCount.branchId}/${stockCount.stockcntId}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(
                message: error is ApiException ? error.message : 'An unexpected error occurred.',
                onRetry: () => ref.invalidate(stockCountSearchProvider(query)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDropdown() {
    final codes = _statusLabels.keys.toList();
    return DropdownButtonFormField<String?>(
      initialValue: _status,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: codes
          .map((code) => DropdownMenuItem(value: code, child: Text(_statusLabels[code]!, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (value) => setState(() => _status = value),
    );
  }

  Widget _warehouseDropdown(AsyncValue<List<Warehouse>> warehousesAsync) {
    return warehousesAsync.when(
      data: (warehouses) => DropdownButtonFormField<String?>(
        initialValue: _warehouse,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Warehouses', overflow: TextOverflow.ellipsis)),
          for (final w in warehouses) DropdownMenuItem(value: w.code, child: Text(w.code, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (value) => setState(() => _warehouse = value),
      ),
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _openWarehousePicker(AuthSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WarehousePickerSheet(companyId: session.companyId, branchId: session.branchId),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_outlined, size: 48, color: AppColors.neutral.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('No stock counts found.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create Stock Count')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run it to verify it passes**

```bash
flutter test test/features/stock_count/presentation/stock_count_list_page_test.dart
```

Expected: `00:0X +6: All tests passed!`

- [ ] **Step 9: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass, `flutter analyze` clean.

- [ ] **Step 10: Commit**

```bash
git add lib/features/stock_count/presentation/widgets/stock_count_card.dart lib/features/stock_count/presentation/pages/stock_count_list_page.dart test/features/stock_count/presentation/stock_count_list_page_test.dart test/features/stock_count/presentation/widgets/stock_count_card_test.dart
git commit -m "Redesign StockCountCard and StockCountListPage: filters, empty-state create action, pull-to-refresh, warehouse-picker sheet"
```

---

## Task 7: `StockCountDetailPage` redesign

**Files:**
- Modify: `dtsretail_app/lib/features/stock_count/presentation/pages/stock_count_detail_page.dart`
- Test: `dtsretail_app/test/features/stock_count/presentation/pages/stock_count_detail_page_test.dart` (new)

**Interfaces:**
- Consumes: `InfoSectionCard`, `stockCountStatusColor`/`StockCountStatusChip` (Task 3).
- Produces: Rebuilt `StockCountDetailPage` (same public API).

- [ ] **Step 1: Write the failing tests**

Create `dtsretail_app/test/features/stock_count/presentation/pages/stock_count_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/api/api_exception.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/warehouse.dart';
import 'package:dtsretail_app/features/stock_count/domain/repository/stock_count_repository.dart';
import 'package:dtsretail_app/features/stock_count/presentation/pages/stock_count_detail_page.dart';
import 'package:dtsretail_app/features/stock_count/presentation/providers/stock_count_providers.dart';

const _line = StockCountLine(
  productCode: 'P001',
  productTypeCode: 'BOOK',
  productTitle: 'Existing Product',
  priceWithGst: 10,
  cost: 5,
  countQty: 3,
);

const _openCount = StockCount(
  companyId: 'BAS',
  branchId: 'BAS1',
  stockcntId: 'SC001',
  cntType: 'CNT',
  status: 'OPEN',
  stockcntDate: '2020-08-02',
  whseCode: 'BBPOS',
  totalItems: 1,
  totalCountQty: 3,
  totalVarQty: -1,
  dateUpdated: '2020-08-02T10:00:00',
  lines: [_line],
);

class _FakeStockCountRepository implements StockCountRepository {
  _FakeStockCountRepository({this.error});
  final ApiException? error;

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) async {
    if (error != null) throw error!;
    return _openCount;
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async => const [];
}

void main() {
  Widget buildPage(StockCountRepository repo) {
    return ProviderScope(
      overrides: [stockCountRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: StockCountDetailPage(companyId: 'BAS', branchId: 'BAS1', stockcntId: 'SC001'),
      ),
    );
  }

  testWidgets('shows a loading indicator while fetching', (tester) async {
    await tester.pumpWidget(buildPage(_FakeStockCountRepository()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the status, warehouse, variance, and line items once loaded', (tester) async {
    await tester.pumpWidget(buildPage(_FakeStockCountRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('OPEN'), findsWidgets);
    expect(find.text('BBPOS'), findsOneWidget);
    expect(find.text('-1.0'), findsOneWidget);
    expect(find.text('Existing Product'), findsOneWidget);
    expect(find.text('Qty: 3.0'), findsOneWidget);
  });

  testWidgets('shows an error view on failure', (tester) async {
    await tester.pumpWidget(
      buildPage(_FakeStockCountRepository(error: const NetworkException('Unable to reach the server. Check your connection.'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to reach the server. Check your connection.'), findsOneWidget);
  });

  testWidgets('shows an Edit FAB for an OPEN count', (tester) async {
    await tester.pumpWidget(buildPage(_FakeStockCountRepository()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FloatingActionButton, 'Edit'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/stock_count/presentation/pages/stock_count_detail_page_test.dart
```

Expected: FAIL — the current page renders `Text('Warehouse: BBPOS')` (not just `'BBPOS'` alone) and plain `ListTile` line items without the new styling.

- [ ] **Step 3: Implement the redesigned `StockCountDetailPage`**

Replace the full contents of `dtsretail_app/lib/features/stock_count/presentation/pages/stock_count_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/info_section_card.dart';
import '../../domain/entities/stock_count_line.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/stock_count_status_chip.dart';

class StockCountDetailPage extends ConsumerWidget {
  const StockCountDetailPage({super.key, required this.companyId, required this.branchId, required this.stockcntId});

  final String companyId;
  final String branchId;
  final String stockcntId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (companyId: companyId, branchId: branchId, stockcntId: stockcntId);
    final detailAsync = ref.watch(stockCountDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(stockcntId)),
      body: detailAsync.when(
        data: (stockCount) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: stockCount.status, isOpen: stockCount.isOpen),
            const SizedBox(height: 16),
            InfoSectionCard(
              title: 'Details',
              rows: [
                ('Warehouse', stockCount.whseCode),
                ('Last updated', stockCount.dateUpdated),
                ('Total variance', stockCount.totalVarQty.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Lines', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in stockCount.lines) _LineRow(line: line),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error is ApiException ? error.message : 'An unexpected error occurred.',
          onRetry: () => ref.invalidate(stockCountDetailProvider(args)),
        ),
      ),
      floatingActionButton: detailAsync.maybeWhen(
        data: (stockCount) => stockCount.isOpen
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/stock-counts/new?companyId=$companyId&branchId=$branchId&stockcntId=$stockcntId'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

/// Prominent, color-coded banner surfacing the stock count's current status
/// — the edit flow only allows editing while OPEN, so this must be
/// unmistakable before the user attempts to edit. Colors now come from
/// [stockCountStatusColor] (the same mapping StockCountCard's chip uses)
/// instead of the old hardcoded green/outline binary.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.isOpen});

  final String status;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = stockCountStatusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(isOpen ? Icons.lock_open : Icons.lock, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            'STATUS: $status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final StockCountLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(line.productCode, style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
              ],
            ),
          ),
          Text('Qty: ${line.countQty}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
flutter test test/features/stock_count/presentation/pages/stock_count_detail_page_test.dart
```

Expected: `00:0X +4: All tests passed!`

- [ ] **Step 5: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: all tests pass, `flutter analyze` clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/stock_count/presentation/pages/stock_count_detail_page.dart test/features/stock_count/presentation/pages/stock_count_detail_page_test.dart
git commit -m "Redesign StockCountDetailPage: signed-status banner, InfoSectionCard, styled line items"
```

---

## Task 8: Manual verification against the running app

**Files:** None (verification only).

- [ ] **Step 1: Run the full suite one more time**

```bash
flutter test
flutter analyze
```

Expected: all tests pass (roughly 110+ tests across the project by now), no analyzer issues.

- [ ] **Step 2: Run the app**

```bash
flutter run
```

- [ ] **Step 3: Visually verify the warehouse-picker flow**

Navigate to Stock Counts, tap "+". Confirm a bottom sheet opens (not a centered dialog), pre-selects a warehouse matching the session's branch, "Start Count" is enabled once a warehouse is chosen, "Cancel" dismisses without navigating, and confirming opens the New Stock Count form with the warehouse shown read-only (no dropdown). Create a count successfully, then tap "+" again — confirm the just-used warehouse is now pre-selected (remembered).

- [ ] **Step 4: Visually verify the list filters and card**

Confirm the Status and Warehouse dropdowns render and re-query on change. Confirm each card shows a colored status chip (Open green, Approved teal, Posted slate), and the variance figure colored by sign (positive green, negative red, zero neutral). Pull down to refresh — confirm it re-queries.

- [ ] **Step 5: Visually verify the empty state**

Filter to a combination with no results (e.g. a status/warehouse pair unlikely to match anything) — confirm the empty state shows with a working "Create Stock Count" button that opens the same warehouse-picker sheet.

- [ ] **Step 6: Visually verify the detail page**

Open a count — confirm the status banner is colored per the same convention as the list card's chip, the Details section renders as a card (not plain text rows), and line items render as styled rows. Confirm the Edit FAB still only appears for OPEN counts, and editing shows the warehouse read-only (matches the existing record).

No commit for this task — it's verification only, not a code change.
