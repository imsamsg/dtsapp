import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_terminal.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_shift_repository.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_terminal_repository.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/pages/pos_shift_list_page.dart';
import 'package:dtsretail_app/features/pos_shift/presentation/providers/pos_shift_providers.dart';

const _terminals = [
  PosTerminal(terminalId: 'T01', displayName: 'Main Counter', branchId: 'BAS1'),
  PosTerminal(terminalId: 'T02', displayName: 'Express Lane', branchId: 'BAS1'),
];

PosShift _shift(String shiftNo, {String? terminalId}) {
  return PosShift(
    companyId: 'BAS',
    branchId: 'BAS1',
    terminalId: terminalId ?? 'T01',
    termName: 'Main Counter',
    shiftNo: shiftNo,
    shiftDateStr: '2026-07-20',
    logOnDateTimeStr: null,
    logOffDateTimeStr: '2026-07-20 17:00:00',
    posOperatorId: null,
    amountCash: 0,
    amountNonCash: 0,
    amountVariance: 0,
    openAmount: 0,
    cashInDraw: 0,
    cashCollected: 0,
    amountDrawn: 0,
    targetAmount: 0,
    totalGstAmount: 0,
    totalBills: 0,
    totalQty: 0,
    totalCost: 0,
    lineDelYN: false,
    totalLineDel: 0,
    voidSaleYN: false,
    totalVoidSale: 0,
    paymentSummary: const [],
  );
}

class _FakePosShiftRepository implements PosShiftRepository {
  _FakePosShiftRepository({this.items = const []});
  List<PosShift> items;
  String? lastTerminalId;
  int searchCallCount = 0;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    searchCallCount++;
    lastTerminalId = terminalId;
    return items;
  }
}

class _FakePosTerminalRepository implements PosTerminalRepository {
  @override
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId}) async =>
      _terminals;
}

void main() {
  Widget buildHarness({required PosShiftRepository shiftRepo, GoRouter? router}) {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/pos-shifts',
          routes: [
            GoRoute(path: '/pos-shifts', builder: (context, state) => const PosShiftListPage()),
          ],
        );

    return ProviderScope(
      overrides: [
        posShiftRepositoryProvider.overrideWithValue(shiftRepo),
        posTerminalRepositoryProvider.overrideWithValue(_FakePosTerminalRepository()),
        authStateProvider.overrideWith(
          (ref) => _FakeAuthStateNotifier(_authenticatedState(), _ReadOnlyRef(container)),
        ),
      ],
      child: MaterialApp.router(routerConfig: effectiveRouter),
    );
  }

  testWidgets('shows shift results for the authenticated session', (tester) async {
    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository(items: [_shift('S1')])));
    await tester.pumpAndSettle();

    expect(find.textContaining('S1'), findsOneWidget);
  });

  testWidgets('changing the terminal filter re-queries with the selected terminal', (tester) async {
    final repo = _FakePosShiftRepository(items: [_shift('S1')]);
    await tester.pumpWidget(buildHarness(shiftRepo: repo));
    await tester.pumpAndSettle();
    expect(repo.lastTerminalId, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Express Lane').last);
    await tester.pumpAndSettle();

    expect(repo.lastTerminalId, 'T02');
  });

  testWidgets('selecting Custom reveals From/To date pickers', (tester) async {
    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository(items: [_shift('S1')])));
    await tester.pumpAndSettle();
    expect(find.textContaining('From:'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<DateRangePreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('From:'), findsOneWidget);
    expect(find.textContaining('To:'), findsOneWidget);
  });

  testWidgets('progressive reveal shows more items on scroll without an extra network call', (tester) async {
    final repo = _FakePosShiftRepository(items: List.generate(45, (i) => _shift('S$i')));
    await tester.pumpWidget(buildHarness(shiftRepo: repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('S19'), findsOneWidget);
    expect(find.textContaining('S20'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await tester.pumpAndSettle();

    expect(find.textContaining('S20'), findsOneWidget);
    expect(repo.searchCallCount, 1);
  });

  testWidgets('pull-to-refresh re-queries', (tester) async {
    final repo = _FakePosShiftRepository(items: [_shift('S1')]);
    await tester.pumpWidget(buildHarness(shiftRepo: repo));
    await tester.pumpAndSettle();
    final callsBeforeRefresh = repo.searchCallCount;

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(repo.searchCallCount, greaterThan(callsBeforeRefresh));
  });

  testWidgets('shows an empty state when no shifts match', (tester) async {
    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No shifts found'), findsOneWidget);
  });

  testWidgets('tapping a card navigates to the detail route with the shift as extra', (tester) async {
    final shift = _shift('S1');
    final router = GoRouter(
      initialLocation: '/pos-shifts',
      routes: [
        GoRoute(
          path: '/pos-shifts',
          builder: (context, state) => const PosShiftListPage(),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (context, state) => Scaffold(body: Text('Detail for ${(state.extra as PosShift).shiftNo}')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(buildHarness(shiftRepo: _FakePosShiftRepository(items: [shift]), router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('S1'));
    await tester.pumpAndSettle();

    expect(find.text('Detail for S1'), findsOneWidget);
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
      features: const ['POS'],
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
