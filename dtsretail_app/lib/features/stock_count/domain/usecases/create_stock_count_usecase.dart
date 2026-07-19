import '../entities/stock_count.dart';
import '../entities/stock_count_line.dart';
import '../repository/stock_count_repository.dart';

class CreateStockCountUsecase {
  CreateStockCountUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCount> call({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    return _repository.create(
      companyId: companyId,
      branchId: branchId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
      userId: userId,
    );
  }
}
