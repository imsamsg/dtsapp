# dtsretail-app: Mobile Foundation Design

## Context

DTS Retail is an existing ERP suite:

- **`D:\Backend\dtsapi`** — mature Spring Boot 3.2.5 backend (Java 21, MySQL `nexgen` database, Flyway-migrated, JWT auth). Actively developed, in production use. This design makes **no changes** to it.
- **`D:\Project\dtsretail-pos`, `dtsretail-inv`, `dtsretail-fin`, `dtsretail-print`** — existing Angular web frontends per module, already built and maintained separately.
- **`D:\Project\dtsretail-app`** (this project) — new, currently empty. A **Flutter mobile companion app** (Android phone first) for on-the-go workflows, calling the existing `dtsapi` REST API. It complements the Angular web apps; it does not replace them.

## Scope of this design

This is the **foundation** build, not the full ERP. It covers:

1. Project scaffolding: feature-first folder structure, theme, routing, API client, core services.
2. Authentication (login, token storage, refresh, logout).
3. Dashboard (navigation shell, feature-gated tiles).
4. First real modules: **Product Catalog** (search/view) and **Stock Count** (list/detail/create/submit), including barcode scanning for adding count lines.

Explicitly out of scope for this pass (each becomes its own future spec, added as a new `features/` folder with no changes to existing code): Mobile POS, Stock Pick, Warehouse transfers, Purchase, Finance/Accounting, Sales, Customer/Supplier management, offline/local-DB support, push notifications, biometric login.

## Backend contract (from `dtsapi`, unchanged)

Base URL: `http://<host>:8081/api/v1/`

**Auth**
- `POST /auth/login` — body `{username, password, companyId?}` → `{loginId, firstName, lastName, fullName, companyId, branchId, roleName, features[], accessToken, refreshToken, tokenType, expiresIn}`. `expiresIn` is in seconds (600 = 10 min per current config, despite `CLAUDE.md` saying 1hr — API docs are authoritative).
- `POST /auth/refresh` — header `X-Refresh-Token` → same response shape with new tokens. Refresh tokens valid 7 days, revocable server-side.
- `POST /auth/revoke` / `POST /auth/revoke-all` — logout / force-logout-all-devices.
- All other endpoints require `Authorization: Bearer {accessToken}`.

**Product Catalog**
- `GET /inventory/products/search?companyId&searchString&searchKey&page&size&sortBy&sortDirection` — paginated product search (`searchKey`: 0=Any,1=Code,3=Barcode,4=Title).
- `GET /inventory/products/{companyId}/{productTypeCode}/{productCode}` — product detail.

**Stock Count**
- `GET /inventory/stock-counts/search?companyId&branchId&searchBy&search&status&...&page&size` — paginated list.
- `GET /inventory/stock-counts/{companyId}/{branchId}/{stockcntId}` — detail with line items.
- `POST /inventory/stock-counts` — create (header `X-User-Id`), body includes `details[]` lines.
- `PUT /inventory/stock-counts/{companyId}/{branchId}/{stockcntId}` — update (replaces all lines).
- `DELETE /inventory/stock-counts/{companyId}/{branchId}/{stockcntId}` — delete.
- `POST /inventory/stock-counts/{companyId}/{branchId}/{stockcntId}/approve` — approve.

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| State management | Riverpod | One provider per feature, testable, no BuildContext coupling |
| Routing | GoRouter | Declarative, supports auth redirect guards, `StatefulShellRoute` for bottom nav |
| API client | Dio | Interceptors for auth header + token refresh |
| Models | Freezed + json_serializable | Immutable DTOs matching API JSON exactly |
| Secure storage | flutter_secure_storage | Access/refresh tokens, never in SharedPreferences |
| Theme | Material 3, DTS green palette from `designs/*.png` | Standard, themeable via `core/theme`; adopts the design reference's brand colors and Login screen composition, not its tablet-width layouts |
| Barcode scanning | `mobile_scanner`, wrapped in one `core/services/barcode_scanner_service.dart` | Camera-based scan; one implementation reused by Product search and Stock Count line entry, and by every future module (Stock Pick, POS, Purchase Receive) without re-implementing |
| Recent searches | `shared_preferences` (small, local-only, non-business data) | UX nicety for Product search; not a business-data cache, so it doesn't conflict with the "no local DB for business data yet" decision below |
| Local DB (business data) | **None yet** | Online-only v1 per explicit decision; add Hive/Isar only when an offline module needs it — but see repository layering below, which prepares for this without a future rewrite |

**Explicitly deferred, not in this pass:** voice search (needs its own UX/permissions/package decision — real scope, not a free accessory), notifications (no backend endpoint found to back a Notifications tile yet), `permissions[]`-based authorization (would require a `dtsapi` change to expose per-action permissions instead of `roleName`/`features[]`; good future direction, tracked as a later backend conversation, not something the Flutter app can adopt unilaterally today).

## Project structure

```
lib/
  app/
    app.dart                 # MaterialApp.router, theme wiring
    router.dart               # GoRouter config, StatefulShellRoute (bottom nav), auth redirect guard
    theme/                    # colors, typography, spacing, component themes
    constants/
  core/
    api/
      dio_client.dart         # Dio instance, base URL, timeouts
      auth_interceptor.dart   # attaches Bearer token, handles 401 -> refresh -> retry
      api_exception.dart      # typed error mapping (network, 401, 4xx, 5xx)
    storage/
      secure_token_storage.dart   # tokens + session (flutter_secure_storage)
      recent_searches_storage.dart # local-only UX cache (shared_preferences)
    services/
      barcode_scanner_service.dart   # one reusable scan implementation for all modules
    widgets/                  # AppLoading, AppEmptyState, AppErrorView
  features/
    authentication/
      data/
        datasource/  (remote/ auth_remote_datasource.dart)
        repository/  (auth_repository_impl.dart)
        models/      (LoginRequestDto, LoginResponseDto)
        mappers/     (LoginResponseDto -> AuthSession)
      domain/ (entities: AuthSession; repository interface; usecases: Login, Logout, RefreshToken)
      presentation/ (pages: LoginPage; providers: authProvider/authStateProvider)
    dashboard/
      presentation/ (pages: DashboardPage; widgets: GreetingHeader, SessionInfoCard, QuickActionsGrid; providers: dashboardTilesProvider)
    product/
      data/
        datasource/  (remote/ product_remote_datasource.dart)
        repository/
        models/      (ProductDto)
        mappers/     (ProductDto -> Product)
      domain/ (entities: Product; repository interface — depends only on the interface, not on "remote"; usecases: SearchProducts, GetProductDetail)
      presentation/ (pages: ProductListPage, ProductDetailPage; widgets: ProductCard, RecentSearchesList; providers)
    stock_count/
      data/
        datasource/  (remote/ stock_count_remote_datasource.dart)
        repository/
        models/      (StockCountDto, StockCountLineDto)
        mappers/
      domain/ (entities: StockCount, StockCountLine; repository interface; usecases: SearchStockCounts, GetStockCountDetail, CreateStockCount, UpdateStockCount)
      presentation/
        pages/ (StockCountListPage, StockCountDetailPage, StockCountFormPage)
        widgets/ (StockCountCard, BarcodeScanLineEntry, WarehouseSelector)
        providers/
  shared/
    widgets/  cards/  dialogs/  forms/
main.dart
```

Every feature follows the same `data / domain / presentation` split so adding a new module later (Mobile POS, Stock Pick, ...) means adding a sibling folder under `features/` — no existing files change.

**Offline-readiness without a rewrite:** each feature's `Repository` implementation depends on a `datasource` *interface*, currently satisfied only by `remote/`. When offline support is actually scoped, a `local/` datasource (Hive/Isar-backed) and a sync engine slot in beside `remote/` and the repository starts choosing between them — the domain layer, usecases, and UI never change. This is a structural convention now, not a library added now: no Hive/Isar dependency in this pass.

**DTO isolation:** API JSON deserializes only into `*Dto` classes in `data/models`. A `mapper` converts `Dto → domain entity`. Presentation-layer widgets consume domain entities (or a thin UI-only view model where formatting differs from the domain shape, e.g. currency-formatted strings) — never the raw DTO. This means a `dtsapi` response shape change is a one-file mapper fix, not a ripple through UI code.

## Authentication flow

1. `LoginPage` collects username/password (+ optional companyId if multi-company).
2. `AuthRepository.login()` calls `POST /auth/login`, on success stores `accessToken`, `refreshToken`, `expiresIn`-derived expiry timestamp, and the decoded session (`loginId`, `companyId`, `branchId`, `roleName`, `features`) via `secure_token_storage.dart`.
3. `authStateProvider` (Riverpod) exposes `unauthenticated | authenticated(session) | loading`. `router.dart` redirects to `/login` when unauthenticated, to `/dashboard` otherwise.
4. `AuthInterceptor` (Dio) attaches `Authorization: Bearer {accessToken}` to every request. On a `401` response, it calls `/auth/refresh` with the stored refresh token, updates storage, and retries the original request once. If refresh fails (expired/revoked), it clears storage and forces navigation to `/login`.
5. Logout calls `POST /auth/revoke` with the current refresh token, then clears local storage regardless of API result.

`features[]` from the login/refresh response is cached in the session and used by the dashboard and route guards to show/hide module tiles — no separate permissions call needed.

## Dashboard

Not empty, but built only from data already in the session — no new backend calls. Visually styled per `designs/home.png` (profile card, section cards on a light background), but only using data this pass actually has:

- **Greeting header**: "Good morning/afternoon/evening, {firstName}" (from the login response, day-part computed client-side from device clock).
- **Session info card**: Company (`companyId`), Branch (`branchId`), Role (`roleName`). All already returned by `/auth/login`.
- **"Last login" — dropped, not faked.** The login response has no last-login timestamp, and there's no other endpoint exposing it. Showing a fabricated or device-local-only value under the label "Last Login" would be misleading (looks like account activity, is actually just "last time this phone logged in"). Skipping it rather than inventing data; revisit if `dtsapi` ever exposes real last-login tracking.
- **Quick Actions**: Product Search, New Stock Count, Scan Barcode (opens the shared barcode scanner, routes to product detail or stock-count-line-entry based on what's scanned) — all real, already-scoped actions, no placeholders.
- **Feature tiles**: Product Catalog, Stock Count for this pass; tiles for modules not in `features[]` are hidden entirely (not shown disabled) — mirrors how the backend already scopes access, avoids advertising modules the user can never open.
- No live KPI widgets in v1 — no mobile-dashboard-summary endpoint exists in the API docs, and assembling one from multiple summary calls (POS sales summary, stock alerts) is bigger than "foundation" scope. A KPI row is a natural fast-follow spec once we pick which numbers matter.
- Pull-to-refresh re-validates the session (harmless no-op if token still valid) and re-evaluates `features[]`.

## Product Catalog module

- `ProductListPage`: search bar (debounced), search-key selector (Any/Code/Barcode/Title), paginated results via `GET /inventory/products/search`, infinite-scroll pagination.
- **Recent searches**: last N search terms shown above results when the search box is empty, stored locally via `recent_searches_storage.dart` (`shared_preferences`, device-local, no backend). Cheap UX win, no API dependency.
- Tapping a result or scanning a barcode (via `barcode_scanner_service.dart`) jumps to `ProductDetailPage` (`GET /inventory/products/{companyId}/{productTypeCode}/{productCode}`), showing title, brand, pricing (w/wo GST), cost, UOM, qty on hand.
- `companyId` comes from the logged-in session, not user input.
- Read-only in this pass — no create/edit UI (Save Product endpoint exists server-side but editing product master data from a phone is out of scope for now).
- **Voice search deferred** — it's a real feature (speech-to-text package choice, mic permission flow, partial-transcript UX), not a one-line addition alongside recent searches. Candidate for its own small follow-up spec.

## Stock Count module

- `StockCountListPage`: filtered/paginated list scoped to the session's `companyId`/`branchId`, filters for status and warehouse, via `GET /inventory/stock-counts/search`.
- `StockCountDetailPage`: shows header (warehouse, status, totals) + line items, read-only for counts not in `OPEN` status. Shows the count's `dateUpdated` so a user can visually notice if it was recently touched by someone else (see concurrency note below).
- `StockCountFormPage` (create/edit while `OPEN`):
  - **Warehouse**: `WarehouseSelector` defaults to a warehouse whose `branch_code` matches the session's `branchId` (fetched via `GET /inventory/warehouses?companyId=`), but lets the user switch to any warehouse returned for the company — there is no per-user warehouse authorization concept in `dtsapi` today (checked: `companybranchuser` maps user→branch only, not user→warehouse, and the warehouse-list endpoint has no branch/user filter), so "restrict to authorized warehouses" isn't enforceable client-side without inventing a rule the backend doesn't have. This matches what the Angular app can actually do today.
  - Add lines either by scanning a barcode (via the shared scanner service, looks up product by barcode, prefills title/cost/price) or manual product search, enter `countQty` per line, submit via `POST` (create) or `PUT` (update).
  - **No Approve action in this pass.** Confirmed there is no permission check for approval anywhere today — not in `dtsretail-inv`, not in `dtsapi` (`StockCountController.approve` has no `@PreAuthorize` and hardcodes `"SYSTEM"` as approver, ignoring the actual user). Shipping Approve on mobile would mean either replicating that same unrestricted state on a new surface, or inventing a mobile-only rule that diverges from web — both worse than deferring. Filed as a separate backend task; mobile adds Approve once `dtsapi` has a real permission + audit fix.
  - **Concurrent edits — last-write-wins for v1.** `dtsapi`'s `PUT` has no version/staleness check (confirmed: no `@Version` field, no `dateUpdated` comparison), so two users editing the same count today can already silently overwrite each other in the Angular app. Mobile doesn't add protection the backend can't enforce; this is tracked in the same backend task filed for the approve/audit gaps.
- No delete UI in this pass (endpoint exists, but destructive action from mobile needs its own confirmation-flow design later if wanted).

## Visual design reference

`designs/login.png`, `designs/home.png`, `designs/product_search.png` exist in this repo as the intended long-term visual direction (DTS green brand palette, left sidebar nav, KPI dashboard, rich filterable catalog with cart actions). They were authored at a tablet/web width (persistent side-by-side filter panel) and include modules and data (POS, Stock Pick, Sales KPIs, Notifications, "Last Login") that are out of scope or not backed by any `dtsapi` endpoint today (see Dashboard and Product Catalog sections below — those constraints don't change).

**What this pass adopts from them:** brand color palette (deep green primary, e.g. `#0E6251` / `#0B3D2E`, teal-green CTA buttons, light card-on-tinted-background layout), the Login screen's visual composition (logo mark, "Welcome back" framing, rounded input fields with leading icons, gradient/curved background), and a left-drawer navigation shell (adapted for phone as a slide-out `Drawer`, not the mockup's permanent rail — phone width can't fit a persistent sidebar).

**What this pass does not adopt:** the tablet-width two-column filter panel, cart/checkout icons on product cards, Active/Inactive/Draft status tabs, KPI sales chart, Notifications feed, and "Last Login" — all remain deferred/dropped per the Dashboard and Product Catalog sections, since building them now would mean either fabricating data or reopening scope decisions already made. Future passes that build POS, Stock Pick, or a KPI dashboard should treat these mockups as their reference.

## Navigation

Left `Drawer` (slide-out via hamburger icon in the `AppBar`, per `home.png`'s chrome), not bottom navigation — matches the design reference and the decision to treat `home.png` as the intended pattern over `product_search.png`'s bottom bar.

Drawer items:
1. **Home** (Dashboard)
2. **Product** (Product Catalog)
3. **Stock Count**
4. **Stock Pick** — shown per the design reference, but disabled/greyed with a "Coming soon" tag; not a functional route in this pass
5. **POS** — same treatment as Stock Pick
6. **Settings** — placeholder page in this pass (no settings to configure yet beyond what Logout covers)
7. **Logout** — action, not a route

No standalone "Profile" page/destination: the profile/session-info card lives directly on the Dashboard (per `home.png`), not behind a separate nav item. No Notifications destination or bell icon in this pass — no backend endpoint exists to back it, and an empty/fake notifications feed would be worse than not having one.

## Error handling

- `ApiException` hierarchy: `NetworkException` (no connectivity/timeout), `UnauthorizedException` (401 after failed refresh), `ApiValidationException` (4xx with backend error body), `ServerException` (5xx). Dio interceptor maps raw errors to these.
- `AppErrorView` shared widget renders a retry-able error state; used consistently across list/detail pages instead of ad hoc error text per screen.
- Form submission errors (e.g. stock count save failure) surface as inline snackbar/dialog with the backend's message, not a generic "something went wrong."

## Testing

- Widget tests for `LoginPage` (validation, error display) and `ProductListPage`/`StockCountListPage` (loading/empty/error/data states) using mocked repositories.
- Unit tests for `AuthInterceptor` refresh-and-retry logic and for repository/usecase mapping of API JSON → domain entities.
- No integration/e2e tests against the live `dtsapi` in this pass (would need a test company/branch and stock-count fixtures on the real `nexgen` DB — separate concern).

## Related backend follow-up (separate task, not part of this build)

While grounding the Stock Count design against the real `dtsapi` code, three gaps were found and filed as a standalone task against `D:\Backend\dtsapi` (not part of this Flutter build, doesn't block it): the approve endpoint has no permission check, it hardcodes `"SYSTEM"` as the approver instead of the real user, and stock count updates have no optimistic-locking/staleness check. Mobile Approve support is intentionally deferred until that's resolved (see Stock Count module section above).
