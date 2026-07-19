// Smoke test for the app shell: verifies the auth-guard redirect wired up in
// lib/app/router.dart actually gates navigation end-to-end (DtsRetailApp ->
// GoRouter -> LoginPage / DashboardPage), rather than just unit-testing the
// redirect callback in isolation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/app/app.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('unauthenticated users are redirected to the login screen', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(const AuthUnauthenticated(), _ReadOnlyRef(container)),
          ),
        ],
        child: const DtsRetailApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DTS Retail'), findsOneWidget);
    expect(find.byKey(const Key('username_field')), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('authenticated users land on the dashboard behind AppPageScaffold', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = AuthSession(
      loginId: 'jdoe',
      firstName: 'Jane',
      lastName: 'Doe',
      fullName: 'Jane Doe',
      companyId: 'DTS',
      branchId: 'HQ',
      roleName: 'Staff',
      features: const [],
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(AuthAuthenticated(session), _ReadOnlyRef(container)),
          ),
        ],
        child: const DtsRetailApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget); // AppBar title on DashboardPage
    expect(find.text('Dashboard'), findsOneWidget); // stub body content
    expect(find.byIcon(Icons.menu), findsOneWidget); // hamburger opens AppDrawer
  });
}

/// Test-only [AuthStateNotifier] that pins [state] to a fixed value and never
/// performs the real, I/O-bound session restoration.
///
/// See test/features/authentication/presentation/login_page_test.dart for
/// the rationale behind subclassing (required by the StateNotifierProvider's
/// generic bound) and overriding only [restoreSession].
class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(AuthState initial, Ref ref) : super(ref) {
    state = initial;
  }

  @override
  Future<void> restoreSession() async {
    // No-op: prevents the real (unmocked) SecureTokenStorage read that the
    // base constructor would otherwise trigger.
  }
}

/// Minimal [Ref] stub that forwards only [read] to a real [ProviderContainer]
/// and fails loudly for anything else, rather than silently returning null
/// for unhandled members (as a `noSuchMethod`-catch-all stub would).
class _ReadOnlyRef implements Ref {
  _ReadOnlyRef(this._container);

  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected Ref member invoked on test stub: ${invocation.memberName}. '
      'Only read() is supported.',
    );
  }
}
