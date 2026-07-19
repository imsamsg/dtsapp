import '../repository/auth_repository.dart';

class LogoutUsecase {
  LogoutUsecase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String refreshToken) => _repository.logout(refreshToken);
}
