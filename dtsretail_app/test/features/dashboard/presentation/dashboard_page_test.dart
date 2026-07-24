import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dtsretail_app/core/services/barcode_scanner_service.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/dashboard/presentation/pages/dashboard_page.dart';

/// Fake [BarcodeScannerService] that returns a fixed value instead of pushing
/// the real (untestable, camera-backed) scanner UI. Mirrors the pattern in
/// `test/features/stock_count/presentation/stock_count_form_page_test.dart`.
class _FakeBarcodeScannerService implements BarcodeScannerService {
  _FakeBarcodeScannerService(this.barcode);

  final String? barcode;

  @override
  Future<String?> scan(BuildContext context) async => barcode;
}

/// Grows the test surface so all five quick-action tiles render on screen at
/// once. The default 800x600 test viewport clips the grid below the fold,
/// which makes `tap()` hit-test against nothing (and silently no-op) for the
/// lower tiles.
Future<void> _growSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('shows a greeting, session info, and quick actions for the authenticated session', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Greeting header uses the session's first name.
    expect(find.textContaining('Sam'), findsOneWidget);

    // Session info card surfaces company/branch/role from the session.
    expect(find.text('BAS'), findsOneWidget);
    expect(find.text('BAS1'), findsOneWidget);
    expect(find.text('STAFF'), findsOneWidget);

    // Quick actions: Product Catalog, Stock Count, Scan Barcode, and POS are
    // enabled links; Stock Pick alone is still shown but disabled, pending
    // its own future feature.
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.text('Stock Count'), findsOneWidget);
    expect(find.text('Scan Barcode'), findsOneWidget);
    expect(find.text('Stock Pick'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(1));
  });

  testWidgets('tapping a disabled quick action does nothing', (tester) async {
    await _growSurface(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock Pick'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Still on the dashboard: no navigation occurred.
    expect(find.text('Quick Actions'), findsOneWidget);
  });

  testWidgets('Product Catalog and Stock Count tiles navigate via GoRouter', (tester) async {
    await _growSurface(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/products', builder: (context, state) => const Scaffold(body: Text('Products Page'))),
        GoRoute(path: '/stock-counts', builder: (context, state) => const Scaffold(body: Text('Stock Counts Page'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock Count'));
    await tester.pumpAndSettle();

    expect(find.text('Stock Counts Page'), findsOneWidget);
  });

  testWidgets('POS tile navigates via GoRouter', (tester) async {
    // POS is the 5th quick action tile, so we need a larger surface to fit all tiles.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/pos-shifts', builder: (context, state) => const Scaffold(body: Text('POS Shifts Page'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('POS'));
    await tester.pumpAndSettle();

    expect(find.text('POS Shifts Page'), findsOneWidget);
  });

  testWidgets('scanning a barcode navigates to Product Catalog and forwards the scanned barcode', (tester) async {
    await _growSurface(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
        GoRoute(
          path: '/products',
          builder: (context, state) => Scaffold(
            body: Text('Products Page: barcode=${state.uri.queryParameters['barcode']}'),
          ),
        ),
        GoRoute(path: '/stock-counts', builder: (context, state) => const Scaffold(body: Text('Stock Counts Page'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
          barcodeScannerServiceProvider.overrideWithValue(_FakeBarcodeScannerService('1234567890')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();

    // The scanned barcode must be forwarded as a query param so the product
    // list page can seed its search from it, rather than landing on an empty
    // list with the scanned value discarded.
    expect(find.text('Products Page: barcode=1234567890'), findsOneWidget);
  });

  testWidgets('cancelling a barcode scan stays on the dashboard', (tester) async {
    await _growSurface(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
          ),
          barcodeScannerServiceProvider.overrideWithValue(_FakeBarcodeScannerService(null)),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Quick Actions'), findsOneWidget);
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
      features: const ['PRODUCT_VIEW', 'STOCK_COUNT'],
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
