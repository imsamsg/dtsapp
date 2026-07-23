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

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.error});

  /// When set, [search] throws this instead of returning a result — used to
  /// simulate a translated [ApiException] reaching the UI.
  final ApiException? error;

  String? lastSearchString;

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

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

/// Fake [BarcodeScannerService] that returns a fixed value instead of pushing
/// the real (untestable, camera-backed) scanner UI. Mirrors the pattern in
/// `test/features/dashboard/presentation/dashboard_page_test.dart`.
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
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
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
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
        ],
        child: const MaterialApp(home: ProductListPage(initialSearch: '2007786553')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Product'), findsOneWidget);
    expect(repo.lastSearchString, '2007786553');
    // The search field reflects the seeded barcode too.
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
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
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
    final repo = _FakeProductRepository(
      error: const NetworkException('Unable to reach the server. Check your connection.'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
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

/// Test-only [AuthStateNotifier] that pins [state] to a fixed value and never
/// performs the real, I/O-bound session restoration. See
/// `test/features/authentication/presentation/login_page_test.dart` for the
/// rationale behind subclassing rather than stubbing `StateNotifier` directly.
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
