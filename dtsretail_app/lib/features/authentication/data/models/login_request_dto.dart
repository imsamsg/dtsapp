import 'package:json_annotation/json_annotation.dart';

part 'login_request_dto.g.dart';

@JsonSerializable()
class LoginRequestDto {
  LoginRequestDto({required this.username, required this.password, this.companyId});

  final String username;
  final String password;
  final String? companyId;

  Map<String, dynamic> toJson() => _$LoginRequestDtoToJson(this);
}
