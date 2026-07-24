import 'package:json_annotation/json_annotation.dart';

part 'pos_terminal_dto.g.dart';

@JsonSerializable(createToJson: false)
class PosTerminalDto {
  PosTerminalDto({
    required this.terminalId,
    this.terminalName,
    this.terminalCode,
    this.displayName,
    required this.branchId,
  });

  final String terminalId;
  final String? terminalName;
  final String? terminalCode;
  final String? displayName;
  final String branchId;

  factory PosTerminalDto.fromJson(Map<String, dynamic> json) => _$PosTerminalDtoFromJson(json);
}
