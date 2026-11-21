import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/domain/entities/pos_terminal.dart';
import 'package:dtsretail_app/features/pos_shift/domain/repository/pos_terminal_repository.dart';
import 'package:dtsretail_app/features/pos_shift/domain/usecases/get_terminals_by_branch_usecase.dart';

class _FakePosTerminalRepository implements PosTerminalRepository {
  String? capturedCompanyId;
  String? capturedBranchId;

  @override
  Future<List<PosTerminal>> getTerminalsByBranch({required String companyId, required String branchId}) async {
    capturedCompanyId = companyId;
    capturedBranchId = branchId;
    return const [PosTerminal(terminalId: 'T01', displayName: 'Main POS', branchId: 'BAS1')];
  }
}

void main() {
  test('forwards companyId and branchId to the repository', () async {
    final repo = _FakePosTerminalRepository();
    final usecase = GetTerminalsByBranchUsecase(repo);

    final result = await usecase(companyId: 'BAS', branchId: 'BAS1');

    expect(repo.capturedCompanyId, 'BAS');
    expect(repo.capturedBranchId, 'BAS1');
    expect(result, hasLength(1));
    expect(result.first.displayName, 'Main POS');
  });
}
