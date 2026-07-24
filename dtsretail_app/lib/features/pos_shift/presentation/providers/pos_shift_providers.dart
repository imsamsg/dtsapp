import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/pos_shift_remote_datasource.dart';
import '../../data/datasource/remote/pos_terminal_remote_datasource.dart';
import '../../data/repository/pos_shift_repository_impl.dart';
import '../../data/repository/pos_terminal_repository_impl.dart';
import '../../domain/entities/pos_terminal.dart';
import '../../domain/repository/pos_shift_repository.dart';
import '../../domain/repository/pos_terminal_repository.dart';
import '../../domain/usecases/get_terminals_by_branch_usecase.dart';
import '../../domain/usecases/search_pos_shifts_usecase.dart';

final posShiftRemoteDatasourceProvider = Provider((ref) => PosShiftRemoteDatasource(ref.watch(dioClientProvider)));
final posTerminalRemoteDatasourceProvider = Provider((ref) => PosTerminalRemoteDatasource(ref.watch(dioClientProvider)));

final posShiftRepositoryProvider = Provider<PosShiftRepository>((ref) {
  return PosShiftRepositoryImpl(ref.watch(posShiftRemoteDatasourceProvider));
});

final posTerminalRepositoryProvider = Provider<PosTerminalRepository>((ref) {
  return PosTerminalRepositoryImpl(ref.watch(posTerminalRemoteDatasourceProvider));
});

final searchPosShiftsUsecaseProvider = Provider((ref) => SearchPosShiftsUsecase(ref.watch(posShiftRepositoryProvider)));
final getTerminalsByBranchUsecaseProvider =
    Provider((ref) => GetTerminalsByBranchUsecase(ref.watch(posTerminalRepositoryProvider)));

final terminalsByBranchProvider =
    FutureProvider.family<List<PosTerminal>, ({String companyId, String branchId})>((ref, args) {
  return ref.watch(getTerminalsByBranchUsecaseProvider)(companyId: args.companyId, branchId: args.branchId);
});

/// UI-only preset — never serialized to the backend as a string (the query
/// always carries resolved `fromDate`/`toDate`), so a typed enum is used
/// rather than a raw string.
enum DateRangePreset { today, last7Days, last30Days, custom }

class PosShiftSearchQuery {
  const PosShiftSearchQuery({
    required this.companyId,
    required this.branchId,
    this.terminalId,
    required this.fromDate,
    required this.toDate,
  });

  final String companyId;
  final String branchId;
  final String? terminalId;
  final DateTime fromDate;
  final DateTime toDate;

  @override
  bool operator ==(Object other) =>
      other is PosShiftSearchQuery &&
      other.companyId == companyId &&
      other.branchId == branchId &&
      other.terminalId == terminalId &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(companyId, branchId, terminalId, fromDate, toDate);
}
