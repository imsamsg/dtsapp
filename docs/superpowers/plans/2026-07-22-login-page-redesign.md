# Login Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `LoginPage` to match the brand's visual direction (gradient header, logo mark, rounded icon-prefixed fields) and add a Remember Me feature, without touching the authentication flow, API contract, or routing.

**Architecture:** Pure presentation-layer change plus one small new storage class. `LoginPage` is rebuilt visually inside the same file; a new `RememberedUsernameStorage` (SharedPreferences-backed, mirrors the existing `RecentSearchesStorage` pattern) is consumed by `LoginPage` only. `AuthStateNotifier`, `LoginUsecase`, and the router are untouched.

**Tech Stack:** Flutter 3.44.6 / Dart ^3.8.1, Riverpod (`flutter_riverpod`), `shared_preferences` (already a dependency), Flutter's built-in autofill (`AutofillGroup`/`AutofillHints`) — no new packages.

## Global Constraints

- Brand palette (from `designs/appdesign.png`): primary `#0F766E`, accent `#14BBA6`, surface tint `#F0FDF4`, danger `#EF4444`. `primaryDark` (`#0B4F49`) is a manually darkened shade of primary for the gradient's dark end — not in the swatch sheet.
- Username field label stays **"Username"**, not "Email or Username" — `dtsapi` only accepts username login.
- Login button label is **"Sign In"** with a trailing arrow icon; loading state shows a spinner *and* the text **"Signing In..."**.
- Out of scope, do not add: "Forgot Password?", "Contact Admin", footer version text, Poppins/custom fonts, dark theme, bottom navigation.
- Existing widget `Key`s (`username_field`, `password_field`, `login_button`) and validator strings (`'Username is required'`, `'Password is required'`) must not change — existing tests in `test/features/authentication/presentation/login_page_test.dart` must keep passing unmodified.
- Remember Me persists **only the username**, **only after a successful login** (never on a failed attempt), via a single-purpose `RememberedUsernameStorage` class (not a generalized "preferences" abstraction — no other field is scoped).
- All `flutter test` commands below assume the working directory is `dtsretail_app/` (the Flutter project root inside the worktree).

---

## Task 1: Update brand palette and add the DTS logo mark asset

**Files:**
- Modify: `dtsretail_app/lib/app/theme/app_theme.dart`
- Modify: `dtsretail_app/pubspec.yaml`
- Create: `dtsretail_app/assets/images/dts_logo_mark.png` (generated from `designs/appdesign.png`)

**Interfaces:**
- Produces: `AppColors.primary` (`#0F766E`), `AppColors.primaryDark` (`#0B4F49`), `AppColors.accent` (`#14BBA6`), `AppColors.surfaceTint` (`#F0FDF4`), `AppColors.danger` (`#EF4444`) — all `static const Color`. Asset path `'assets/images/dts_logo_mark.png'` available to `Image.asset(...)`.
- Consumes: `designs/appdesign.png` (already present in this worktree's `designs/` folder — verify with `ls ../designs` from `dtsretail_app/` before starting; if missing, it needs to be copied in from the main repo's `designs/` folder first).

- [ ] **Step 1: Generate the logo mark asset**

From the `dtsretail_app/` directory:

```bash
mkdir -p assets/images
python -c "
from PIL import Image
im = Image.open('../designs/appdesign.png')
tight = im.crop((296, 563, 363, 625))
tight.save('assets/images/dts_logo_mark.png')
print('saved', tight.size)
"
```

Expected output: `saved (67, 62)`. (If Python lacks Pillow: `pip install pillow` first.) This crops the DTS hexagon glyph + wordmark from `appdesign.png`'s "Brand & Logo" section — a plain, mostly-white-background crop (source has no real transparency), which is fine since Task 3 places it inside a Flutter-drawn white/`colorScheme.surface` card, so the image's white background blends seamlessly with the card behind it.

- [ ] **Step 2: Register the asset in `pubspec.yaml`**

In `dtsretail_app/pubspec.yaml`, find this existing comment block under the `flutter:` section (around line 63-66):

```yaml
  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg
```

Leave those comment lines as-is, and add a real `assets:` key directly below them:

```yaml
  assets:
    - assets/images/dts_logo_mark.png
```

- [ ] **Step 3: Update `AppColors` with the exact brand palette**

Replace the full contents of `dtsretail_app/lib/app/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

/// Palette sourced from designs/appdesign.png's brand color swatches.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0F766E); // teal-green CTA / brand accent
  static const primaryDark = Color(0xFF0B4F49); // gradient header dark end (manual shade; not in the swatch sheet)
  static const accent = Color(0xFF14BBA6); // secondary accent, gradient mid-tone
  static const surfaceTint = Color(0xFFF0FDF4); // light card-on-tinted-background
  static const danger = Color(0xFFEF4444); // error state
}

final ThemeData appThemeLight = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  scaffoldBackgroundColor: AppColors.surfaceTint,
  appBarTheme: const AppBarTheme(centerTitle: false, backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(48)),
  ),
);
```

Note: `AppColors.primaryDark` is also used by `lib/shared/widgets/app_drawer.dart` (Drawer background) — this is an intentional, expected side effect: the drawer picks up the same brand-accurate shade. No code change needed there.

- [ ] **Step 4: Verify no regressions**

```bash
flutter pub get
flutter analyze
flutter test
```

Expected: `flutter pub get` succeeds (new asset registered), `flutter analyze` reports no new issues, `flutter test` — all existing tests still pass (this task doesn't touch any widget behavior, only constants and an asset).

- [ ] **Step 5: Commit**

```bash
git add lib/app/theme/app_theme.dart pubspec.yaml assets/images/dts_logo_mark.png
git commit -m "Update brand palette to exact appdesign.png hex values, add DTS logo mark asset"
```

---

## Task 2: Add `RememberedUsernameStorage`

**Files:**
- Create: `dtsretail_app/lib/core/storage/remembered_username_storage.dart`
- Test: `dtsretail_app/test/core/storage/remembered_username_storage_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences` (from the `shared_preferences` package, already a dependency).
- Produces: `RememberedUsernameStorage(SharedPreferences prefs)` with `String? read()`, `Future<void> save(String username)`, `Future<void> clear()`; and `final rememberedUsernameStorageProvider = FutureProvider<RememberedUsernameStorage>(...)`. Task 4 consumes both.

- [ ] **Step 1: Write the failing test**

Create `dtsretail_app/test/core/storage/remembered_username_storage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/remembered_username_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when nothing is stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);

    expect(storage.read(), isNull);
  });

  test('save then read round-trips the username', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);

    await storage.save('sam.tan');

    expect(storage.read(), 'sam.tan');
  });

  test('clear removes a previously saved username', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RememberedUsernameStorage(prefs);

    await storage.save('sam.tan');
    await storage.clear();

    expect(storage.read(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/core/storage/remembered_username_storage_test.dart
```

Expected: FAIL to compile — `Target of URI doesn't exist: 'package:dtsretail_app/core/storage/remembered_username_storage.dart'` (the class doesn't exist yet).

- [ ] **Step 3: Implement `RememberedUsernameStorage`**

Create `dtsretail_app/lib/core/storage/remembered_username_storage.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberedUsernameStorage {
  RememberedUsernameStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'remembered_username';

  String? read() => _prefs.getString(_key);

  Future<void> save(String username) => _prefs.setString(_key, username);

  Future<void> clear() => _prefs.remove(_key);
}

final rememberedUsernameStorageProvider = FutureProvider<RememberedUsernameStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RememberedUsernameStorage(prefs);
});
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/core/storage/remembered_username_storage_test.dart
```

Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/storage/remembered_username_storage.dart test/core/storage/remembered_username_storage_test.dart
git commit -m "Add RememberedUsernameStorage"
```

---

## Task 3: Redesign `LoginPage` visual layout

**Files:**
- Modify: `dtsretail_app/lib/features/authentication/presentation/pages/login_page.dart`
- Test: `dtsretail_app/test/features/authentication/presentation/login_page_test.dart` (add `setUp` mock and two new tests; existing two tests unmodified)

**Interfaces:**
- Consumes: `AppColors` (Task 1), `authStateProvider`/`AuthLoading`/`AuthUnauthenticated`/`AuthAuthenticated` (existing, unchanged), `'assets/images/dts_logo_mark.png'` (Task 1).
- Produces: Rebuilt `LoginPage` widget tree (same public API: `const LoginPage({super.key})`, same `Key`s). This task does **not** yet wire Remember Me persistence — the checkbox exists visually and is locally interactive, but `_submit` doesn't touch storage yet (that's Task 4). `_LoginPageState` gains `_obscurePassword`, `_rememberMe` fields and an entrance `AnimationController` that Task 4 will extend, not replace.

- [ ] **Step 1: Add the required `setUp` mock to the existing test file**

`shared_preferences` isn't used by `LoginPage` yet, but Task 4 will make every build of `LoginPage` resolve `rememberedUsernameStorageProvider`, which calls `SharedPreferences.getInstance()`. Doing this now keeps the test file green through both tasks. Edit `dtsretail_app/test/features/authentication/presentation/login_page_test.dart`: add near the top of `main()`, before the existing two `testWidgets`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

(add to the import list at the top of the file), then as the first line inside `void main() {`:

```dart
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
```

- [ ] **Step 2: Rewrite `LoginPage`**

Replace the full contents of `dtsretail_app/lib/features/authentication/presentation/pages/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthUnauthenticated ? authState.errorMessage : null;
    final colorScheme = Theme.of(context).colorScheme;
    final headerHeight = MediaQuery.of(context).size.height * 0.38;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: _LoginHeader(height: headerHeight),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFormCard(colorScheme, isLoading, errorMessage),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(ColorScheme colorScheme, bool isLoading, String? errorMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('username_field'),
                controller: _usernameController,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Username is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('password_field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  suffixIcon: IconButton(
                    key: const Key('password_visibility_toggle'),
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    key: const Key('remember_me_checkbox'),
                    value: _rememberMe,
                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                  ),
                  const Text('Remember me'),
                ],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(errorMessage, style: TextStyle(color: colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('login_button'),
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 12),
                          Text('Signing In...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sign In'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    await ref.read(authStateProvider.notifier).login(
          username: username,
          password: _passwordController.text,
        );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderCurveClipper(),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -30, right: -30, child: _softCircle(90, Colors.white.withValues(alpha: 0.08))),
            Positioned(bottom: 40, left: -40, child: _softCircle(110, Colors.white.withValues(alpha: 0.06))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _LogoMark(),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage your inventory',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Image.asset('assets/images/dts_logo_mark.png', fit: BoxFit.contain),
    );
  }
}

class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 32);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 32);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
```

- [ ] **Step 3: Run the existing tests to verify they still pass**

```bash
flutter test test/features/authentication/presentation/login_page_test.dart
```

Expected: `00:0X +2: All tests passed!` — the two pre-existing tests (empty-form validation, error-message display) pass unmodified against the new layout, since the `Key`s and validator strings didn't change.

- [ ] **Step 4: Give the fake notifier a configurable login outcome**

The upcoming keyboard-dismiss test taps "Sign In" on a fully valid form, which calls `AuthStateNotifier.login()`. The existing `_FakeAuthStateNotifier` only overrides `restoreSession`, not `login` — letting the tap hit the real, network-calling `login()` risks a flaky or hanging test (nothing mocks Dio here). Fix this once, now, so every test after this point can opt into a deterministic outcome instead. In `dtsretail_app/test/features/authentication/presentation/login_page_test.dart`, replace the existing `_FakeAuthStateNotifier` class with:

```dart
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
```

This is a superset of the existing class — every call site so far (`_FakeAuthStateNotifier(someState, someRef)`) still compiles unchanged since `loginResult` is optional and defaults to `null`, which leaves `login()` a safe no-op (state simply doesn't change, no network call). Re-run the pre-existing two tests to confirm nothing broke:

```bash
flutter test test/features/authentication/presentation/login_page_test.dart
```

Expected: `00:0X +2: All tests passed!`

- [ ] **Step 5: Add the password-visibility-toggle test**

Add to the same file, as a new `testWidgets` inside `main()`:

```dart
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
```

- [ ] **Step 6: Add the keyboard-dismiss-on-submit test**

Add another `testWidgets` to the same file. This one passes `loginResult` so submitting a valid form never touches the network:

```dart
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

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus?.hasFocus, isFalse);
  });
```

`FocusScope.of(context).unfocus()` runs synchronously at the top of `_submit`, before the `await` on `login(...)`, so focus is already cleared regardless of what `loginResult` resolves to — `pumpAndSettle` here just drains the (now instant, no-network) login call cleanly instead of leaving anything pending.

- [ ] **Step 7: Run the full test file**

```bash
flutter test test/features/authentication/presentation/login_page_test.dart
```

Expected: `00:0X +4: All tests passed!` (2 pre-existing + password-toggle + keyboard-dismiss).

- [ ] **Step 8: Manual visual check**

Run `flutter run` (or use an already-running emulator/device) and navigate to `/login` (or log out if already authenticated) to visually confirm: gradient header with curved bottom edge, DTS logo mark centered in a white rounded card, "Welcome back" / subtitle text, rounded icon-prefixed fields, password toggle works, "Sign In" button with arrow. Compare against `designs/appdesign.png`'s small login screen thumbnail and `designs/product_search.png` (the mislabeled login mockup).

- [ ] **Step 9: Commit**

```bash
git add lib/features/authentication/presentation/pages/login_page.dart test/features/authentication/presentation/login_page_test.dart
git commit -m "Redesign LoginPage: gradient header, logo mark, rounded fields, password toggle, autofill, keyboard dismiss"
```

---

## Task 4: Wire Remember Me into `LoginPage`

**Files:**
- Modify: `dtsretail_app/lib/features/authentication/presentation/pages/login_page.dart`
- Test: `dtsretail_app/test/features/authentication/presentation/login_page_test.dart`

**Interfaces:**
- Consumes: `RememberedUsernameStorage`, `rememberedUsernameStorageProvider` (Task 2); `AuthAuthenticated`, `AuthStateNotifier.login` (existing, unchanged — confirmed `login()` always settles `state` to either `AuthAuthenticated` or `AuthUnauthenticated` before returning, so the caller can safely check `ref.read(authStateProvider)` immediately after `await`ing it).
- Produces: `LoginPage` prefills a remembered username and checks "Remember me" on load; saves/clears the remembered username only after a successful login.

- [ ] **Step 1: Write the failing tests**

`_FakeAuthStateNotifier` already supports a configurable `loginResult` (added in Task 3, step 4) — no class changes needed here. Add to `dtsretail_app/test/features/authentication/presentation/login_page_test.dart` these three new `testWidgets`:

```dart
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
```

Add the new imports this requires at the top of the file:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/remembered_username_storage.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
```

(`shared_preferences` may already be imported from Task 3, step 1 — don't duplicate the import.)

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
flutter test test/features/authentication/presentation/login_page_test.dart
```

Expected: FAIL — the "remembers the username" and "does not persist" tests fail because `_submit` doesn't touch `rememberedUsernameStorageProvider` yet; the "prefills" test fails because nothing populates `_usernameController`/`_rememberMe` from storage on load.

- [ ] **Step 3: Wire Remember Me into `LoginPage`**

In `dtsretail_app/lib/features/authentication/presentation/pages/login_page.dart`:

Add the storage import alongside the existing ones:

```dart
import '../../../../core/storage/remembered_username_storage.dart';
```

In `_LoginPageState`, extend `initState` to load the remembered username:

```dart
  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _entranceController.forward();
    _loadRememberedUsername();
  }

  Future<void> _loadRememberedUsername() async {
    final storage = await ref.read(rememberedUsernameStorageProvider.future);
    final saved = storage.read();
    if (saved != null && mounted) {
      setState(() {
        _usernameController.text = saved;
        _rememberMe = true;
      });
    }
  }
```

Replace `_submit` to persist after a confirmed successful login:

```dart
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    await ref.read(authStateProvider.notifier).login(
          username: username,
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (ref.read(authStateProvider) is AuthAuthenticated) {
      final storage = await ref.read(rememberedUsernameStorageProvider.future);
      if (_rememberMe) {
        await storage.save(username);
      } else {
        await storage.clear();
      }
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/authentication/presentation/login_page_test.dart
```

Expected: `00:0X +7: All tests passed!` (2 original + 2 from Task 3 + 3 new).

- [ ] **Step 5: Run the full test suite**

```bash
flutter test
```

Expected: all tests across the project pass — this confirms Task 1's palette change and Task 2/4's new storage class didn't regress anything elsewhere (e.g. `app_drawer.dart` picking up the new `primaryDark` shade).

- [ ] **Step 6: Commit**

```bash
git add lib/features/authentication/presentation/pages/login_page.dart test/features/authentication/presentation/login_page_test.dart
git commit -m "Wire Remember Me: prefill on load, persist only after successful login"
```

---

## Task 5: Manual verification against the running app

**Files:** None (verification only).

- [ ] **Step 1: Run the app**

```bash
flutter run
```

(Or use an already-running emulator — this project's foundation plan notes the emulator reaches the host backend at `http://10.0.2.2:8081/api/v1`.)

- [ ] **Step 2: Visually verify the login screen**

Check against `designs/appdesign.png`'s login thumbnail and `designs/product_search.png`:
- Gradient header (dark green → primary green) with a curved bottom edge, two faint circular accents.
- White rounded card with the DTS logo mark, "Welcome back", subtitle.
- Form card overlapping the header, rounded icon-prefixed Username/Password fields.
- Password field's eye icon toggles obscured/visible text.
- "Remember me" checkbox present, unchecked by default on first run.
- "Sign In" button with trailing arrow; shows spinner + "Signing In..." while a login is in flight.

- [ ] **Step 3: Verify Remember Me end-to-end**

- Log in once with "Remember me" checked. Log out. Return to `/login`: username should be prefilled and the checkbox checked.
- Log out again, uncheck "Remember me" before logging in, log in successfully. Log out, return to `/login`: username field should be empty and checkbox unchecked (the previous remembered value was cleared).
- Attempt a login with a wrong password while "Remember me" is checked: after the failure, kill and restart the app (or navigate away and back) — the username field should **not** have been persisted from this failed attempt (it reflects whatever was remembered from the last *successful* login, or nothing).

- [ ] **Step 4: Verify autofill and keyboard dismiss**

On a real device or emulator with saved credentials in the platform's autofill service, confirm the username/password fields offer autofill suggestions. Confirm the on-screen keyboard closes immediately when "Sign In" is tapped.

No commit for this task — it's verification only, not a code change.
