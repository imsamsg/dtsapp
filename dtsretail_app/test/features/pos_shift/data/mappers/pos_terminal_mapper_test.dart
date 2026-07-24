import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/pos_shift/data/mappers/pos_terminal_mapper.dart';
import 'package:dtsretail_app/features/pos_shift/data/models/pos_terminal_dto.dart';

void main() {
  test('prefers displayName when present', () {
    final dto = PosTerminalDto(
      terminalId: 'T01',
      displayName: 'Main POS',
      terminalName: 'POS1',
      terminalCode: 'T01C',
      branchId: 'BAS1',
    );
    expect(dto.toDomain().displayName, 'Main POS');
  });

  test('falls back to terminalName when displayName is missing', () {
    final dto = PosTerminalDto(terminalId: 'T01', terminalName: 'POS1', terminalCode: 'T01C', branchId: 'BAS1');
    expect(dto.toDomain().displayName, 'POS1');
  });

  test('falls back to terminalCode when displayName and terminalName are missing', () {
    final dto = PosTerminalDto(terminalId: 'T01', terminalCode: 'T01C', branchId: 'BAS1');
    expect(dto.toDomain().displayName, 'T01C');
  });

  test('falls back to the raw terminalId when no name fields are present', () {
    final dto = PosTerminalDto(terminalId: 'T01', branchId: 'BAS1');
    expect(dto.toDomain().displayName, 'T01');
  });
}
