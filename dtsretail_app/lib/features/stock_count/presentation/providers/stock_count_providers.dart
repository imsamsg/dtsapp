import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/stock_count_remote_datasource.dart';
import '../../data/datasource/remote/warehouse_remote_datasource.dart';
import '../../data/repository/stock_count_repository_impl.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repository/stock_count_repository.dart';
import '../../domain/usecases/create_stock_count_usecase.dart';
import '../../domain/usecases/get_stock_count_detail_usecase.dart';
import '../../domain/usecases/search_stock_counts_usecase.dart';
import '../../domain/usecases/update_stock_count_usecase.dart';

final stockCountRemoteDatasourceProvider = Provider((ref) => StockCountRemoteDatasource(ref.watch(dioClientProvider)));
final warehouseRemoteDatasourceProvider = Provider((ref) => WarehouseRemoteDatasource(ref.watch(dioClientProvider)));

final stockCountRepositoryProvider = Provider<StockCountRepository>((ref) {
  return StockCountRepositoryImpl(
    ref.watch(stockCountRemoteDatasourceProvider),
    ref.watch(warehouseRemoteDatasourceProvider),
  );
});

final searchStockCountsUsecaseProvider = Provider((ref) => SearchStockCountsUsecase(ref.watch(stockCountRepositoryProvider)));
final getStockCountDetailUsecaseProvider = Provider((ref) => GetStockCountDetailUsecase(ref.watch(stockCountRepositoryProvider)));
final createStockCountUsecaseProvider = Provider((ref) => CreateStockCountUsecase(ref.watch(stockCountRepositoryProvider)));
final updateStockCountUsecaseProvider = Provider((ref) => UpdateStockCountUsecase(ref.watch(stockCountRepositoryProvider)));

class StockCountSearchQuery {
  const StockCountSearchQuery({required this.companyId, required this.branchId, this.status});
  final String companyId;
  final String branchId;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is StockCountSearchQuery && other.companyId == companyId && other.branchId == branchId && other.status == status;

  @override
  int get hashCode => Object.hash(companyId, branchId, status);
}

final stockCountSearchProvider = FutureProvider.family<StockCountSearchResult, StockCountSearchQuery>((ref, query) {
  return ref.watch(searchStockCountsUsecaseProvider)(companyId: query.companyId, branchId: query.branchId, status: query.status);
});

final stockCountDetailProvider = FutureProvider.family<StockCount, ({String companyId, String branchId, String stockcntId})>(
  (ref, args) {
    return ref.watch(getStockCountDetailUsecaseProvider)(
      companyId: args.companyId,
      branchId: args.branchId,
      stockcntId: args.stockcntId,
    );
  },
);

final warehousesProvider = FutureProvider.family<List<Warehouse>, String>((ref, companyId) {
  return ref.watch(stockCountRepositoryProvider).getWarehouses(companyId: companyId);
});
