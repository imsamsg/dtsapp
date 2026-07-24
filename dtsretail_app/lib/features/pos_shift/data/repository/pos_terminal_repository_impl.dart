import '../datasource/remote/pos_terminal_remote_datasource.dart';
import '../mappers/pos_terminal_mapper.dart';
import '../../domain/entities/pos_terminal.dart';
import '../../domain/repository/pos_terminal_repository.dart';

class PosTerminalRepositoryImpl implements PosTerminalRepository {
  PosTerminalRepositoryImpl(this._remote);

  final PosTerminalRemoteDatasource _remote;

  @override
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId}) async {
    final dtos = await _remote.getTerminalsByBranch(companyId: companyId, branchId: branchId);
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
