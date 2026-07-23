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

    expect(find.text('Unable to reach the server. Check your connection.'), findsOneWidget);
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
    // A single tester.drag() moves the scrollable by exactly the given delta
    // (it is not clamped to maxScrollExtent like a real fling would be), so
    // the offset must exceed the grid's full scroll extent at the test
    // viewport's default size (~5865px for 20 two-column cards) plus the
    // 300px near-bottom threshold in _onScroll. -10000 comfortably clears it.
    await tester.drag(find.byType(GridView), const Offset(0, -10000));
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
