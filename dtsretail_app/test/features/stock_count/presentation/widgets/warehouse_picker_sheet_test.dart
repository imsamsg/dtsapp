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
