# dtsretail-app: Login Page Redesign

## Context

The foundation spec (`2026-07-19-mobile-app-foundation-design.md`) committed to adopting the visual composition of the login mockup — logo mark, "Welcome back" framing, rounded icon-prefixed fields, gradient/curved background — but the shipped `LoginPage` (`lib/features/authentication/presentation/pages/login_page.dart`) is a bare Material `Form` with no styling beyond the app's global theme (colors via `FilledButton`).

The mockup itself is misfiled in this repo: `designs/product_search.png` is actually the login screen (a "Welcome back" sign-in card on a green gradient), and `designs/login.png` is actually the product catalog/filters screen. This spec treats `designs/product_search.png` as the login reference, consistent with the intent already recorded in the foundation spec.

`designs/appdesign.png` was added later as a fuller brand/component reference (logo lockups, exact color palette, typography, icon set, component library, and small app-screen thumbnails). This spec adopts its logo asset and color palette (both directly applicable to login); typography (Poppins) and its bottom-navigation component are **not** adopted here — see "Explicitly out of scope."

## Scope

Redesign `LoginPage`'s visual layout and add one small piece of genuinely-backed functionality (Remember Me). No changes to the authentication flow, API contract, routing, or any other page.

**Explicitly out of scope:**
- "Forgot Password?" — no `dtsapi` endpoint.
- "Contact Admin" — no admin contact data in the session or API.
- Footer version line — no real app-version source to display; mockup's "v2.4.0" is not a real value.
- Warehouse-shelf photo / dot-grid decorative patterns — pure decoration, not worth the implementation cost.
- "Email or Username" label — `dtsapi` login only accepts username, not email; the field stays labeled "Username" so the UI doesn't imply a capability that doesn't exist.
- **Poppins typography** — `appdesign.png`'s typography section is an app-wide `TextTheme`/font-dependency change affecting every screen, not a login-page concern. `app.dart` currently wires a single `theme: appThemeLight` with no font configuration. Candidate for its own future spec.
- **Dark mode** — `app.dart` has no `darkTheme` configured anywhere today. This spec switches hardcoded colors to `Theme.of(context).colorScheme` values for Material 3 consistency, but that is not the same as adding dark mode support, since there's no dark theme to switch into yet.
- **Bottom navigation** — `appdesign.png`'s component library shows a bottom nav bar, which conflicts with the Drawer nav the foundation spec already chose and shipped (Task 7). Not revisited here.

## Brand reference update

`appdesign.png`'s color palette is more precise than the by-eye sampling in the current `AppColors` (`lib/app/theme/app_theme.dart`). Updating to the authoritative hex values:

| Token | Old | New | Use |
|---|---|---|---|
| `primary` | `#0E6251` | `#0F766E` | CTA buttons, brand accent |
| `primaryDark` | `#0B3D2E` | *(derived — see below)* | Gradient header start |
| `accent` *(new)* | — | `#14BBA6` | Secondary accent, gradient mid-tone |
| `surfaceTint` | `#F3F7F5` | `#F0FDF4` | Light card-on-tinted background |
| `danger` *(new)* | — | `#EF4444` | Error text (was theme-default `colorScheme.error`) |

`primaryDark` isn't in the swatch sheet directly; keep it as a darker manual shade of `primary` (`#0F766E` darkened, e.g. `#0B4F49`) for the gradient's dark end, since the sheet doesn't provide one. `#34D399`, `#D1FAE5`, `#64748B`, `#0F172A`, `#F59E0B` are not used by the login page and are left for whichever future spec needs tonal buttons, chips, or warning states.

## Logo asset

`appdesign.png`'s "Brand & Logo" section contains a pre-rendered lockup: a white rounded-square card with a green hexagon glyph and "DTS" text — a pixel-accurate match for the login mockup's logo element. Cropping this into `assets/images/dts_logo_card.png` (transparent or white background) and registering it in `pubspec.yaml`'s `assets:` list. `LoginPage` renders it with `Image.asset`, replacing the earlier CustomPaint/Icon plan. No other logo variants (the solid-green icon, the full horizontal "DTS RETAIL" wordmark) are needed for this page.

## Visual design

`LoginPage` body becomes:

1. **Header band** — height responsive via `MediaQuery.of(context).size.height * 0.38` (or `LayoutBuilder`) rather than a fixed pixel height, so it scales sensibly on small (iPhone SE) and foldable screens. A `ClipPath` container with a single curved bottom edge, filled with a linear gradient from `AppColors.primaryDark` to `AppColors.primary`. Two soft-edged, low-opacity circles (plain `Container`/`BoxDecoration` with `RadialGradient` or soft `BoxShadow`, not `ImageFilter.blur`, to avoid backdrop-filter repaint cost) sit behind the content for a bit of depth, in place of the mockup's dot-grid/photo. Contains, centered:
   - `Image.asset('assets/images/dts_logo_card.png')` at a fixed reasonable size (e.g. 64x64–80x80).
   - "Welcome back" (`headlineMedium` or similar, light text for contrast against the gradient).
   - "Sign in to manage your inventory" subtitle (lighter weight, light text).
2. **Form card** — a rounded-top-corner card (background `Theme.of(context).colorScheme.surface`, not hardcoded `Colors.white`) overlapping the bottom of the header band, wrapped in an `AutofillGroup`, containing the existing `Form`:
   - Username field (`Key('username_field')`, unchanged validator/message), leading person/mail icon, rounded border, `autofillHints: [AutofillHints.username]`.
   - Password field (`Key('password_field')`, unchanged validator/message), leading lock icon, `autofillHints: [AutofillHints.password]`, trailing `IconButton` that toggles `obscureText` (local widget state) with `tooltip`: "Show password" / "Hide password" (icon-only button — the one place this page needs an explicit accessibility label; `TextFormField`'s `labelText` and `FilledButton`'s built-in button semantics already cover the rest, so no blanket `Semantics()` wrapping elsewhere).
   - "Remember me" checkbox + label row, default unchecked (behavior below).
   - Inline error text when `AuthUnauthenticated.errorMessage` is set — unchanged from today.
   - Full-width `FilledButton` (`Key('login_button')`): label "Sign In" with a trailing arrow icon; while `AuthLoading`, shows a small spinner *and* "Signing In..." text instead of a bare spinner.
3. **Entrance animation** — lightweight, implicit-animation only (no new package): logo/header fades in, form card slides up slightly, ~300ms total on page load.

`_submit` calls `FocusScope.of(context).unfocus()` first to dismiss the keyboard, matching existing behavior otherwise.

All existing widget `Key`s and validator message strings (`'Username is required'`, `'Password is required'`) are preserved unchanged so the existing `login_page_test.dart` continues to pass without modification.

## Remember Me

New `lib/core/storage/remembered_username_storage.dart`, following the existing `RecentSearchesStorage` pattern (SharedPreferences-backed, single-purpose file — not generalized into a broader "login preferences" store, since no other field is scoped anywhere today; matches the foundation spec's pattern of not building for unscoped future needs):

```dart
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

`LoginPage` behavior:
- On `initState`, asynchronously resolves `rememberedUsernameStorageProvider.future`; if a stored username exists, prefills `_usernameController` and sets the checkbox to checked. Defaults to unchecked with an empty field otherwise.
- In `_submit`: `await ref.read(authStateProvider.notifier).login(...)` first. `AuthStateNotifier.login()` (unchanged) always settles `state` to either `AuthAuthenticated` or `AuthUnauthenticated` before returning, so after the `await` completes, check `ref.read(authStateProvider)`:
  - If `AuthAuthenticated`: `save()` the username if the checkbox is checked, else `clear()` any previously stored value.
  - If `AuthUnauthenticated` (failed login): do nothing — a failed attempt never touches stored state, so a mistyped username on a failed login can't get persisted.
  - Password is never persisted, in either case.

## Testing

- Existing `login_page_test.dart` assertions (validation errors, error message display) continue to pass unmodified since keys/messages don't change.
- New widget test: password visibility toggle switches `obscureText` on the password field.
- New widget test: when `RememberedUsernameStorage` has a saved value (via provider override), the username field is prefilled and the checkbox starts checked.
- New widget test: a failed login (mocked `AuthUnauthenticated` with `errorMessage`) does not call `save`/`clear` on the storage.
- New unit test for `RememberedUsernameStorage`: save/read/clear round-trip, mirroring the existing `recent_searches_storage_test.dart` pattern.

## Non-goals

No changes to `AuthStateNotifier`, `LoginUsecase`, routing, or the API contract. No company-ID field added (mockup doesn't show one; existing `LoginUsecase` already supports an optional `companyId` unused by the UI, unchanged by this spec). No Poppins/typography change, no dark mode support, no bottom-navigation change — all flagged above as out of scope.
