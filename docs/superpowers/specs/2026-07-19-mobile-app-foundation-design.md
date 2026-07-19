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
| Routing | GoRouter | Declarative, supports auth redirect guards |
| API client | Dio | Interceptors for auth header + token refresh |
| Models | Freezed + json_serializable | Immutable DTOs matching API JSON exactly |
| Secure storage | flutter_secure_storage | Access/refresh tokens, never in SharedPreferences |
| Theme | Material 3 | Standard, themeable via `core/theme` |
| Barcode scanning | `mobile_scanner` | Camera-based scan for stock count lines |
| Local DB | **None yet** | Online-only v1 per explicit decision; add Hive/Isar only when an offline module needs it |

## Project structure

```
lib/
  app/
    app.dart                 # MaterialApp.router, theme wiring
    router.dart               # GoRouter config + auth redirect guard
    theme/                    # colors, typography, spacing, component themes
    constants/
  core/
    api/
      dio_client.dart         # Dio instance, base URL, timeouts
      auth_interceptor.dart   # attaches Bearer token, handles 401 -> refresh -> retry
      api_exception.dart      # typed error mapping (network, 401, 4xx, 5xx)
    storage/
      secure_token_storage.dart
    services/                 # (empty for now; barcode/permission helpers land here as needed)
    widgets/                  # AppLoading, AppEmptyState, AppErrorView
  features/
    authentication/
      data/  (datasource, repository, models: LoginRequest/LoginResponse)
      domain/ (entities: AuthSession; repository interface; usecases: Login, Logout, RefreshToken)
      presentation/ (pages: LoginPage; providers: authProvider/authStateProvider)
    dashboard/
      presentation/ (pages: DashboardPage; widgets: FeatureTile; providers: dashboardTilesProvider)
    product/
      data/ (datasource, repository, models: ProductModel)
      domain/ (entities: Product; repository interface; usecases: SearchProducts, GetProductDetail)
      presentation/ (pages: ProductListPage, ProductDetailPage; widgets: ProductCard; providers)
    stock_count/
      data/ (datasource, repository, models: StockCountModel, StockCountLineModel)
      domain/ (entities: StockCount, StockCountLine; repository interface; usecases: SearchStockCounts, GetStockCountDetail, CreateStockCount, UpdateStockCount, ApproveStockCount)
      presentation/
        pages/ (StockCountListPage, StockCountDetailPage, StockCountFormPage)
        widgets/ (StockCountCard, BarcodeScanLineEntry)
        providers/
  shared/
    widgets/  cards/  dialogs/  forms/
main.dart
```

Every feature follows the same `data / domain / presentation` split so adding a new module later (Mobile POS, Stock Pick, ...) means adding a sibling folder under `features/` — no existing files change.

## Authentication flow

1. `LoginPage` collects username/password (+ optional companyId if multi-company).
2. `AuthRepository.login()` calls `POST /auth/login`, on success stores `accessToken`, `refreshToken`, `expiresIn`-derived expiry timestamp, and the decoded session (`loginId`, `companyId`, `branchId`, `roleName`, `features`) via `secure_token_storage.dart`.
3. `authStateProvider` (Riverpod) exposes `unauthenticated | authenticated(session) | loading`. `router.dart` redirects to `/login` when unauthenticated, to `/dashboard` otherwise.
4. `AuthInterceptor` (Dio) attaches `Authorization: Bearer {accessToken}` to every request. On a `401` response, it calls `/auth/refresh` with the stored refresh token, updates storage, and retries the original request once. If refresh fails (expired/revoked), it clears storage and forces navigation to `/login`.
5. Logout calls `POST /auth/revoke` with the current refresh token, then clears local storage regardless of API result.

`features[]` from the login/refresh response is cached in the session and used by the dashboard and route guards to show/hide module tiles — no separate permissions call needed.

## Dashboard

- Simple grid/list of `FeatureTile`s: Product Catalog, Stock Count for this pass; other known modules render in a disabled/"coming soon" state if not in `features[]`, hidden entirely if the backend doesn't grant that feature at all (exact hide-vs-disable rule: hide if absent from `features[]`, since that mirrors how the backend already scopes access).
- No live KPI widgets in v1 — I didn't find a single mobile-dashboard-summary endpoint in the API docs, and bolting together multiple summary calls (POS sales summary, stock alerts) is bigger than "foundation" scope. Tiles are pure navigation for now; a KPI row is a natural fast-follow spec once we pick which numbers matter.
- Pull-to-refresh re-validates the session (harmless no-op if token still valid) and re-evaluates `features[]`.

## Product Catalog module

- `ProductListPage`: search bar (debounced), search-key selector (Any/Code/Barcode/Title), paginated results via `GET /inventory/products/search`, infinite-scroll pagination.
- Tapping a result or scanning a barcode (via `mobile_scanner`) jumps to `ProductDetailPage` (`GET /inventory/products/{companyId}/{productTypeCode}/{productCode}`), showing title, brand, pricing (w/wo GST), cost, UOM, qty on hand.
- `companyId` comes from the logged-in session, not user input.
- Read-only in this pass — no create/edit UI (Save Product endpoint exists server-side but editing product master data from a phone is out of scope for now).

## Stock Count module

- `StockCountListPage`: filtered/paginated list scoped to the session's `companyId`/`branchId`, filters for status and warehouse, via `GET /inventory/stock-counts/search`.
- `StockCountDetailPage`: shows header (warehouse, status, totals) + line items, read-only for counts not in `OPEN` status.
- `StockCountFormPage` (create/edit while `OPEN`): add lines either by scanning a barcode (looks up product via the Product Catalog search-by-barcode, prefills title/cost/price) or manual product search, enter `countQty` per line, submit via `POST` (create) or `PUT` (update). Approve action calls the approve endpoint and is only shown for authorized roles (gated by `features[]`/`roleName`, exact rule to confirm against how the Angular inventory app gates this today).
- No delete UI in this pass (endpoint exists, but destructive action from mobile needs its own confirmation-flow design later if wanted).

## Error handling

- `ApiException` hierarchy: `NetworkException` (no connectivity/timeout), `UnauthorizedException` (401 after failed refresh), `ApiValidationException` (4xx with backend error body), `ServerException` (5xx). Dio interceptor maps raw errors to these.
- `AppErrorView` shared widget renders a retry-able error state; used consistently across list/detail pages instead of ad hoc error text per screen.
- Form submission errors (e.g. stock count save failure) surface as inline snackbar/dialog with the backend's message, not a generic "something went wrong."

## Testing

- Widget tests for `LoginPage` (validation, error display) and `ProductListPage`/`StockCountListPage` (loading/empty/error/data states) using mocked repositories.
- Unit tests for `AuthInterceptor` refresh-and-retry logic and for repository/usecase mapping of API JSON → domain entities.
- No integration/e2e tests against the live `dtsapi` in this pass (would need a test company/branch and stock-count fixtures on the real `nexgen` DB — separate concern).

## Open items to confirm with the Angular inventory app before Stock Count implementation

- Exact role/feature check used to gate "Approve" — should match `dtsretail-inv`'s existing rule rather than inventing a new one.
- Whether `whseCode` should be user-selectable at count-creation time or defaulted from the user's assigned branch/warehouse (same question applies to the existing web app).
