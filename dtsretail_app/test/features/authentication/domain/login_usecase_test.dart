import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/domain/repository/auth_repository.dart';
import 'package:dtsretail_app/features/authentication/domain/usecases/login_usecase.dart';

class _FakeAuthRepository implements AuthRepository {
  String? capturedUsername;
  String? capturedPassword;
  String? capturedCompanyId;

  @override
  Future<AuthSession> login({required String username, required String password, String? companyId}) async {
    capturedUsername = username;
    capturedPassword = password;
    capturedCompanyId = companyId;
    return AuthSession(
      loginId: username,
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: companyId ?? 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW'],
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<AuthSession> refresh(String refreshToken) => throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();
}

void main() {
  test('LoginUsecase passes credentials through and returns the session', () async {
    final fakeRepo = _FakeAuthRepository();
    final usecase = LoginUsecase(fakeRepo);

    final session = await usecase(username: 'SAM', password: '270179', companyId: 'BAS');

    expect(fakeRepo.capturedUsername, 'SAM');
    expect(fakeRepo.capturedPassword, '270179');
    expect(fakeRepo.capturedCompanyId, 'BAS');
    expect(session.loginId, 'SAM');
    expect(session.features, contains('PRODUCT_VIEW'));
  });
}
