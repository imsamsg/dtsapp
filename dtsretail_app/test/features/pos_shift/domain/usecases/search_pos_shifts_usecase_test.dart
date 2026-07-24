import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_shift.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_shift_repository.dart';
import 'package:dtsretail_app/features/pos_shift/domain/usecases/search_pos_shifts_usecase.dart';

class _FakePosShiftRepository implements PosShiftRepository {
  String? capturedTerminalId;
  DateTime? capturedFromDate;
  DateTime? capturedToDate;

  @override
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    capturedTerminalId = terminalId;
    capturedFromDate = fromDate;
    capturedToDate = toDate;
    return const [];
  }
}

void main() {
  test('defaults terminalId/date range to null', () async {
    final repo = _FakePosShiftRepository();
    final usecase = SearchPosShiftsUsecase(repo);

    await usecase(companyId: 'BAS', branchId: 'BAS1');

    expect(repo.capturedTerminalId, isNull);
    expect(repo.capturedFromDate, isNull);
    expect(repo.capturedToDate, isNull);
  });

  test('forwards terminalId and date range', () async {
    final repo = _FakePosShiftRepository();
    final usecase = SearchPosShiftsUsecase(repo);
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 20);

    await usecase(companyId: 'BAS', branchId: 'BAS1', terminalId: 'T01', fromDate: from, toDate: to);

    expect(repo.capturedTerminalId, 'T01');
    expect(repo.capturedFromDate, from);
    expect(repo.capturedToDate, to);
  });
}
