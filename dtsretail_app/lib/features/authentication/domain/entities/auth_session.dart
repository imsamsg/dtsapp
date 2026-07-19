import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';

@freezed
class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String loginId,
    required String firstName,
    required String lastName,
    required String fullName,
    required String companyId,
    required String branchId,
    required String roleName,
    required List<String> features,
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
  }) = _AuthSession;

  const AuthSession._();

  bool get isAccessTokenExpired => DateTime.now().isAfter(accessTokenExpiresAt);
}
