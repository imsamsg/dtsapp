import '../entities/stock_count.dart';
import '../repository/stock_count_repository.dart';

class SearchStockCountsUsecase {
  SearchStockCountsUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCountSearchResult> call({
    required String companyId,
    required String branchId,
    String? status,
    int page = 0,
    int size = 20,
  }) {
    return _repository.search(companyId: companyId, branchId: branchId, status: status, page: page, size: size);
  }
}
