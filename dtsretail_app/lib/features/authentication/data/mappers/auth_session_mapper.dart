import '../models/login_response_dto.dart';
import '../../domain/entities/auth_session.dart';

extension LoginResponseDtoMapper on LoginResponseDto {
  AuthSession toDomain() {
    return AuthSession(
      loginId: loginId,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      companyId: companyId,
      branchId: branchId,
      roleName: roleName,
      features: features,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}
