import 'package:json_annotation/json_annotation.dart';

part 'login_response_dto.g.dart';

@JsonSerializable()
class LoginResponseDto {
  LoginResponseDto({
    required this.loginId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.companyId,
    required this.branchId,
    required this.roleName,
    required this.features,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String loginId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String companyId;
  final String branchId;
  final String roleName;
  final List<String> features;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) => _$LoginResponseDtoFromJson(json);
}
