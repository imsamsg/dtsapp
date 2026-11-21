import '../entities/pos_terminal.dart';
import '../repository/pos_terminal_repository.dart';

class GetTerminalsByBranchUsecase {
  GetTerminalsByBranchUsecase(this._repository);

  final PosTerminalRepository _repository;

  Future<List<PosTerminal>> call({required String companyId, required String branchId}) {
    return _repository.getTerminalsByBranch(companyId: companyId, branchId: branchId);
  }
}
