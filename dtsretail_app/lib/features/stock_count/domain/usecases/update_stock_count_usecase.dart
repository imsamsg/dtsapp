import '../entities/stock_count.dart';
import '../entities/stock_count_line.dart';
import '../repository/stock_count_repository.dart';

class UpdateStockCountUsecase {
  UpdateStockCountUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCount> call({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    return _repository.update(
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
      userId: userId,
    );
  }
}
