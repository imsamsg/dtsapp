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
