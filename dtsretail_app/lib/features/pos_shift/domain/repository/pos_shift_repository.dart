import '../entities/pos_shift.dart';

abstract interface class PosShiftRepository {
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  });
}
