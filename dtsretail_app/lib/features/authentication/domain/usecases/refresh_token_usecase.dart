import '../entities/auth_session.dart';
import '../repository/auth_repository.dart';

class RefreshTokenUsecase {
  RefreshTokenUsecase(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call(String refreshToken) => _repository.refresh(refreshToken);
}
