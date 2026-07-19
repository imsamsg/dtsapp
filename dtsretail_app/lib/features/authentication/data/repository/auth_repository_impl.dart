import '../datasource/remote/auth_remote_datasource.dart';
import '../mappers/auth_session_mapper.dart';
import '../models/login_request_dto.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDatasource _remote;

  @override
  Future<AuthSession> login({required String username, required String password, String? companyId}) async {
    final dto = await _remote.login(LoginRequestDto(username: username, password: password, companyId: companyId));
    return dto.toDomain();
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final dto = await _remote.refresh(refreshToken);
    return dto.toDomain();
  }

  @override
  Future<void> logout(String refreshToken) => _remote.revoke(refreshToken);
}
