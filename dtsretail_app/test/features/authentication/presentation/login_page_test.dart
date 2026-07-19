import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/api/dio_client.dart';
import 'package:dtsretail_app/core/storage/secure_token_storage.dart';
import 'package:dtsretail_app/features/authentication/presentation/pages/login_page.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('shows validation errors when submitting empty form', (tester) async {
    final container = ProviderContainer(
      overrides: [
        dioClientProvider.overrideWithValue(Dio()),
        secureTokenStorageProvider.overrideWithValue(SecureTokenStorage(const FlutterSecureStorage())),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _StubNotifier(
              const AuthUnauthenticated(),
              _ContainerRef(container),
            ),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows error message when auth state is unauthenticated with errorMessage', (tester) async {
    final container = ProviderContainer(
      overrides: [
        dioClientProvider.overrideWithValue(Dio()),
        secureTokenStorageProvider.overrideWithValue(SecureTokenStorage(const FlutterSecureStorage())),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _StubNotifier(
              const AuthUnauthenticated(errorMessage: 'Invalid username or password.'),
              _ContainerRef(container),
            ),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password.'), findsOneWidget);
  });
}

class _StubNotifier extends AuthStateNotifier {
  _StubNotifier(AuthState initial, Ref ref) : super(ref) {
    state = initial;
  }
}

class _ContainerRef implements Ref {
  _ContainerRef(this._container);

  final ProviderContainer _container;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod && invocation.memberName == #read) {
      return _container.read(invocation.positionalArguments.first);
    }
    return null;
  }
}
