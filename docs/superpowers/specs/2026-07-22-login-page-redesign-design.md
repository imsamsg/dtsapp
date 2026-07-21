# dtsretail-app: Login Page Redesign

## Context

The foundation spec (`2026-07-19-mobile-app-foundation-design.md`) committed to adopting the visual composition of the login mockup — logo mark, "Welcome back" framing, rounded icon-prefixed fields, gradient/curved background — but the shipped `LoginPage` (`lib/features/authentication/presentation/pages/login_page.dart`) is a bare Material `Form` with no styling beyond the app's global theme (colors via `FilledButton`).

The mockup itself is misfiled in this repo: `designs/product_search.png` is actually the login screen (a "Welcome back" sign-in card on a green gradient), and `designs/login.png` is actually the product catalog/filters screen. This spec treats `designs/product_search.png` as the login reference, consistent with the intent already recorded in the foundation spec.

## Scope

Redesign `LoginPage`'s visual layout and add one small piece of genuinely-backed functionality (Remember Me). No changes to the authentication flow, API contract, routing, or any other page.

**Explicitly out of scope** (mockup elements with no backend/product support today):
- "Forgot Password?" — no `dtsapi` endpoint.
- "Contact Admin" — no admin contact data in the session or API.
- Footer version line — no real app-version source to display; mockup's "v2.4.0" is not a real value.
- Warehouse-shelf photo / dot-grid decorative patterns — pure decoration, not worth the implementation cost.
- "Email or Username" label — `dtsapi` login only accepts username, not email; the field stays labeled "Username" so the UI doesn't imply a capability that doesn't exist.

## Visual design

`LoginPage` body becomes:

1. **Header band** — a `ClipPath` container with a single curved bottom edge, filled with a linear gradient from `AppColors.primaryDark` to `AppColors.primary` (both already defined in `app_theme.dart`). Contains, centered:
   - A white rounded-square "logo card" containing a green hexagon glyph (drawn with `CustomPaint` or `Icons.hexagon`, no image asset) and "DTS" text.
   - "Welcome back" (`headlineMedium` or similar, white/light text for contrast).
   - "Sign in to manage your inventory" subtitle (lighter weight, white/light text).
2. **Form card** — a white, rounded-top-corner card overlapping the bottom of the header band, containing the existing `Form`:
   - Username field (`Key('username_field')`, unchanged validator/message), leading person/mail icon, rounded border matching the mockup's field style.
   - Password field (`Key('password_field')`, unchanged validator/message), leading lock icon, trailing `IconButton` that toggles `obscureText` (local widget state — pure UI, no new state management).
   - "Remember me" checkbox + label row (behavior below).
   - Inline error text when `AuthUnauthenticated.errorMessage` is set — unchanged from today.
   - Full-width `FilledButton` (`Key('login_button')`), trailing arrow icon, same loading-spinner-when-`AuthLoading` behavior as today.

All existing widget `Key`s and validator message strings (`'Username is required'`, `'Password is required'`) are preserved unchanged so the existing `login_page_test.dart` continues to pass without modification.

## Remember Me

New `lib/core/storage/remembered_username_storage.dart`, following the existing `RecentSearchesStorage` pattern (SharedPreferences-backed):

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
- On `initState`, asynchronously resolves `rememberedUsernameStorageProvider.future`; if a stored username exists, prefills `_usernameController` and sets the checkbox to checked. Defaults to unchecked with an empty field otherwise (not defaulted to checked).
- In `_submit`, before calling `authStateProvider.notifier.login(...)`: if the checkbox is checked, `save()` the current username; if unchecked, `clear()` any stored value. Password is never persisted.

## Testing

- Existing `login_page_test.dart` assertions (validation errors, error message display) continue to pass unmodified since keys/messages don't change.
- New widget test: password visibility toggle switches `obscureText` on the password field.
- New widget test: when `RememberedUsernameStorage` has a saved value (via provider override), the username field is prefilled and the checkbox starts checked.
- New unit test for `RememberedUsernameStorage`: save/read/clear round-trip (mirrors any existing `RecentSearchesStorage` test if one exists, else a plain SharedPreferences-mocked test).

## Non-goals

No changes to `AuthStateNotifier`, `LoginUsecase`, routing, or the API contract. No company-ID field added (mockup doesn't show one; existing `LoginUsecase` already supports an optional `companyId` unused by the UI, unchanged by this spec).
