import '../datasource/remote/pos_shift_remote_datasource.dart';
import '../mappers/pos_shift_mapper.dart';
import '../../domain/entities/pos_shift.dart';
import '../../domain/repository/pos_shift_repository.dart';

class PosShiftRepositoryImpl implements PosShiftRepository {
  PosShiftRepositoryImpl(this._remote);

  final PosShiftRemoteDatasource _remote;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final dtos = await _remote.search(
      companyId: companyId,
      branchId: branchId,
      terminalId: terminalId,
      fromDate: fromDate,
      toDate: toDate,
    );
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
