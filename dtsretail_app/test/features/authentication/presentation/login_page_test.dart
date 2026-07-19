import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/authentication/presentation/pages/login_page.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('shows validation errors when submitting empty form', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(const AuthUnauthenticated(), _ReadOnlyRef(container)),
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(
              const AuthUnauthenticated(errorMessage: 'Invalid username or password.'),
              _ReadOnlyRef(container),
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

/// Test-only [AuthStateNotifier] that pins [state] to a fixed value and never
/// performs the real, I/O-bound session restoration.
///
/// Subclassing [AuthStateNotifier] here is unavoidable, not a shortcut:
/// `authStateProvider` is declared as
/// `StateNotifierProvider<AuthStateNotifier, AuthState>`, and Riverpod's
/// `overrideWith` requires the override factory to return an
/// `AuthStateNotifier` (or subtype) — a plain `StateNotifier<AuthState>` does
/// not satisfy that generic bound and fails to compile against this provider.
///
/// What makes construction deterministic (rather than "happens to work
/// today") is overriding [restoreSession] — the *only* method the base
/// constructor calls that performs real I/O (a `SecureTokenStorage`
/// platform-channel read) — with a no-op. Dart dispatches instance method
/// calls virtually even from within a superclass constructor, so the base
/// constructor's `restoreSession()` call resolves to this override, and the
/// real, unmocked storage/platform channel is structurally never touched —
/// not merely unlikely to resolve before assertions run.
///
/// `_wireInterceptor()` (also invoked from the base constructor) is left to
/// run for real: it only performs synchronous, in-memory work (adding an
/// interceptor to a `Dio` instance) with no I/O, so it cannot introduce
/// flakiness.
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
