import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/remembered_username_storage.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/pages/login_page.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('password visibility toggle switches obscureText', (tester) async {
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

    EditableText editableText() => tester.widget<EditableText>(
          find.descendant(of: find.byKey(const Key('password_field')), matching: find.byType(EditableText)),
        );

    expect(editableText().obscureText, isTrue);

    await tester.tap(find.byKey(const Key('password_visibility_toggle')));
    await tester.pump();

    expect(editableText().obscureText, isFalse);
  });

  testWidgets('dismisses the keyboard when the form is submitted', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(
              const AuthUnauthenticated(),
              _ReadOnlyRef(container),
              loginResult: const AuthUnauthenticated(errorMessage: 'Invalid username or password.'),
            ),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('username_field')), 'sam.tan');
    await tester.tap(find.byKey(const Key('password_field')));
    await tester.enterText(find.byKey(const Key('password_field')), 'secret');
    await tester.pump();

    // Capture the actual focus node (the password field's) rather than
    // re-querying FocusManager.instance.primaryFocus after the tap: the
    // default `unfocus()` disposition (UnfocusDisposition.scope) moves
    // primary focus to the enclosing FocusScope rather than to null, and
    // `primaryFocus?.hasFocus` is tautologically true for whatever node is
    // currently primaryFocus (hasFocus includes hasPrimaryFocus, which by
    // definition holds for the node itself). Checking the captured node's
    // hasFocus after the tap is what actually verifies focus moved away.
    final passwordFieldFocus = FocusManager.instance.primaryFocus;
    expect(passwordFieldFocus?.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(passwordFieldFocus?.hasFocus, isFalse);
  });

  testWidgets('remembers the username after a successful login when Remember Me is checked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final fakeSession = AuthSession(
      loginId: 'sam.tan',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW'],
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(
              const AuthUnauthenticated(),
              _ReadOnlyRef(container),
              loginResult: AuthAuthenticated(fakeSession),
            ),
          ),
          rememberedUsernameStorageProvider.overrideWith((ref) async => storage),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('username_field')), 'sam.tan');
    await tester.enterText(find.byKey(const Key('password_field')), 'secret');
    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(storage.read(), 'sam.tan');
  });

  testWidgets('does not persist the username after a failed login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(
              const AuthUnauthenticated(),
              _ReadOnlyRef(container),
              loginResult: const AuthUnauthenticated(errorMessage: 'Invalid username or password.'),
            ),
          ),
          rememberedUsernameStorageProvider.overrideWith((ref) async => storage),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('username_field')), 'wrong.user');
    await tester.enterText(find.byKey(const Key('password_field')), 'wrong');
    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(storage.read(), isNull);
  });

  testWidgets('prefills the username and checks Remember Me when one was previously remembered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);
    await storage.save('sam.tan');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(const AuthUnauthenticated(), _ReadOnlyRef(container)),
          ),
          rememberedUsernameStorageProvider.overrideWith((ref) async => storage),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('sam.tan'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byKey(const Key('remember_me_checkbox')));
    expect(checkbox.value, isTrue);
  });

  testWidgets('clears a previously remembered username after a successful login when Remember Me is unchecked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);
    await storage.save('sam.tan');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final fakeSession = AuthSession(
      loginId: 'sam.tan',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW'],
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _FakeAuthStateNotifier(
              const AuthUnauthenticated(),
              _ReadOnlyRef(container),
              loginResult: AuthAuthenticated(fakeSession),
            ),
          ),
          rememberedUsernameStorageProvider.overrideWith((ref) async => storage),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Username is prefilled and checkbox is checked from previous storage
    expect(find.text('sam.tan'), findsOneWidget);
    final checkboxBefore = tester.widget<Checkbox>(find.byKey(const Key('remember_me_checkbox')));
    expect(checkboxBefore.value, isTrue);

    // Uncheck the Remember Me checkbox
    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.pump();

    // Fill in password and submit
    await tester.enterText(find.byKey(const Key('password_field')), 'secret');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    // Verify storage was cleared
    expect(storage.read(), isNull);
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
  _FakeAuthStateNotifier(AuthState initial, Ref ref, {this.loginResult}) : super(ref) {
    state = initial;
  }

  /// If set, calling [login] sets state to this instead of performing a
  /// real (network-bound) login — lets tests simulate success/failure
  /// deterministically without hitting Dio/the real API.
  final AuthState? loginResult;

  @override
  Future<void> restoreSession() async {
    // No-op: prevents the real (unmocked) SecureTokenStorage read that the
    // base constructor would otherwise trigger.
  }

  @override
  Future<void> login({required String username, required String password, String? companyId}) async {
    if (loginResult != null) {
      state = loginResult!;
    }
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
