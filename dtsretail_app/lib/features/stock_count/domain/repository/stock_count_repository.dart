import '../entities/stock_count.dart';
import '../entities/stock_count_line.dart';
import '../entities/warehouse.dart';

abstract interface class StockCountRepository {
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page,
    int size,
  });

  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId});

  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  });

  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  });

  Future<List<Warehouse>> getWarehouses({required String companyId});
}
