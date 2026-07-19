import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/auth_interceptor.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../data/datasource/remote/auth_remote_datasource.dart';
import '../../data/repository/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});
  final String? errorMessage;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);
  final AuthSession session;
}

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDatasourceProvider));
});

final loginUsecaseProvider = Provider((ref) => LoginUsecase(ref.watch(authRepositoryProvider)));
final logoutUsecaseProvider = Provider((ref) => LogoutUsecase(ref.watch(authRepositoryProvider)));
final refreshTokenUsecaseProvider = Provider((ref) => RefreshTokenUsecase(ref.watch(authRepositoryProvider)));

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._ref) : super(const AuthLoading()) {
    _wireInterceptor();
    restoreSession();
  }

  final Ref _ref;

  void _wireInterceptor() {
    final dio = _ref.read(dioClientProvider);
    final storage = _ref.read(secureTokenStorageProvider);
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        storage,
        (refreshToken) => _ref.read(refreshTokenUsecaseProvider)(refreshToken),
        () => state = const AuthUnauthenticated(),
      ),
    );
  }

  Future<void> restoreSession() async {
    final storage = _ref.read(secureTokenStorageProvider);
    final session = await storage.readSession();
    state = session == null ? const AuthUnauthenticated() : AuthAuthenticated(session);
  }

  Future<void> login({required String username, required String password, String? companyId}) async {
    state = const AuthLoading();
    try {
      final session = await _ref.read(loginUsecaseProvider)(
        username: username,
        password: password,
        companyId: companyId,
      );
      await _ref.read(secureTokenStorageProvider).saveSession(session);
      state = AuthAuthenticated(session);
    } on DioException catch (e) {
      final message = e.response?.statusCode == 401
          ? 'Invalid username or password.'
          : 'Unable to log in. Please try again.';
      state = AuthUnauthenticated(errorMessage: message);
    }
  }

  Future<void> logout() async {
    final current = state;
    if (current is AuthAuthenticated) {
      try {
        await _ref.read(logoutUsecaseProvider)(current.session.refreshToken);
      } catch (_) {
        // Best-effort revoke; clear local session regardless.
      }
    }
    await _ref.read(secureTokenStorageProvider).clear();
    state = const AuthUnauthenticated();
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref);
});
