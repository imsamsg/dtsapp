import '../entities/auth_session.dart';
import '../repository/auth_repository.dart';

class LoginUsecase {
  LoginUsecase(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({required String username, required String password, String? companyId}) {
    return _repository.login(username: username, password: password, companyId: companyId);
  }
}
