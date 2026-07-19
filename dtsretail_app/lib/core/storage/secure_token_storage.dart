import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/authentication/domain/entities/auth_session.dart';

class SecureTokenStorage {
  SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _sessionKey = 'auth_session_json';

  Future<void> saveSession(AuthSession session) async {
    final json = jsonEncode({
      'loginId': session.loginId,
      'firstName': session.firstName,
      'lastName': session.lastName,
      'fullName': session.fullName,
      'companyId': session.companyId,
      'branchId': session.branchId,
      'roleName': session.roleName,
      'features': session.features,
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'accessTokenExpiresAt': session.accessTokenExpiresAt.toIso8601String(),
    });
    await _storage.write(key: _sessionKey, value: json);
  }

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return AuthSession(
      loginId: map['loginId'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      fullName: map['fullName'] as String,
      companyId: map['companyId'] as String,
      branchId: map['branchId'] as String,
      roleName: map['roleName'] as String,
      features: List<String>.from(map['features'] as List),
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      accessTokenExpiresAt: DateTime.parse(map['accessTokenExpiresAt'] as String),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage(const FlutterSecureStorage());
});
