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
