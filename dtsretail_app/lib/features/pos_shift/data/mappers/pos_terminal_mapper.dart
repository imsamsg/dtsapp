import '../models/pos_terminal_dto.dart';
import '../../domain/entities/pos_terminal.dart';

extension PosTerminalDtoMapper on PosTerminalDto {
  /// Mirrors the backend's own termName fallback chain
  /// (PosShiftServiceImpl.mapToDTO): prefer the richest available label,
  /// falling back progressively down to the raw terminal ID.
  PosTerminal toDomain() {
    return PosTerminal(
      terminalId: terminalId,
      displayName: displayName ?? terminalName ?? terminalCode ?? terminalId,
      branchId: branchId,
    );
  }
}
