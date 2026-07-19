import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dtsretail_app/core/storage/secure_token_storage.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeStore = {};

  setUp(() {
    fakeStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'write':
          fakeStore[call.arguments['key']] = call.arguments['value'];
          return null;
        case 'read':
          return fakeStore[call.arguments['key']];
        case 'delete':
          fakeStore.remove(call.arguments['key']);
          return null;
        case 'deleteAll':
          fakeStore.clear();
          return null;
        default:
          return null;
      }
    });
  });

  test('saveSession then readSession round-trips the session', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    final session = AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW', 'STOCK_COUNT'],
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
      accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 12),
    );

    await storage.saveSession(session);
    final result = await storage.readSession();

    expect(result, session);
  });

  test('readSession returns null when nothing stored', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    expect(await storage.readSession(), isNull);
  });

  test('clear removes the stored session', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    final session = AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const [],
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: DateTime.utc(2026, 1, 1),
    );
    await storage.saveSession(session);
    await storage.clear();
    expect(await storage.readSession(), isNull);
  });
}
