import '../entities/stock_count.dart';
import '../repository/stock_count_repository.dart';

class GetStockCountDetailUsecase {
  GetStockCountDetailUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCount> call({required String companyId, required String branchId, required String stockcntId}) {
    return _repository.getDetail(companyId: companyId, branchId: branchId, stockcntId: stockcntId);
  }
}
