import '../entities/pos_shift.dart';
import '../repository/pos_shift_repository.dart';

class SearchPosShiftsUsecase {
  SearchPosShiftsUsecase(this._repository);

  final PosShiftRepository _repository;

  Future<List<PosShift>> call({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return _repository.search(
      companyId: companyId,
      branchId: branchId,
      terminalId: terminalId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
