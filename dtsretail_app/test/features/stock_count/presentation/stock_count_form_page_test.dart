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
    testWidgets('create mode blocks submission until a warehouse and at least one line are present', (tester) async {
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

      expect(find.text('New Stock Count'), findsOneWidget);
      expect(find.text('BBPOS · Main Warehouse'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Select a warehouse and add at least one line.'), findsOneWidget);
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

      // Existing line loaded from the freshly-fetched detail.
      expect(find.text('Existing Product'), findsOneWidget);
      expect(find.text('Edit Stock Count'), findsOneWidget);

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
          child: const MaterialApp(home: StockCountFormPage()),
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
