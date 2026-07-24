import '../entities/pos_terminal.dart';

abstract interface class PosTerminalRepository {
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId});
}
