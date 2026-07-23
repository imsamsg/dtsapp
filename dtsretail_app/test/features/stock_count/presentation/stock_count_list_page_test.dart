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
