# dtsretail-app: Stock Count Redesign

## Context

`StockCountListPage`, `StockCountDetailPage`, and `StockCountFormPage` currently ship with no visual styling beyond default Material widgets (plain `ListTile`s, hardcoded `Colors.green`, plain `Text` rows) and no list filtering — `StockCountSearchQuery` already carries a `status` field but the UI never sets it. "New Stock Count" navigates straight from the list's `+` icon into the full form, which has an inline `WarehouseSelector` at the top.

While scoping this, the real backend `StockCountController.search` (`D:\Backend\dtsapi\...\StockCountController.java:29-37`) was checked directly: it accepts `companyId`, `branchId`, `status`, `warehouse`, `page`, `size` — the `warehouse` filter param exists server-side but was never plumbed through the Flutter datasource. Sort is hardcoded server-side (`stockcntId` descending) — not client-controllable, unlike Product's `sortBy`. The real status lifecycle was confirmed against `StockCountServiceImpl.java`: stock counts move `OPEN` → `APPROVED` → `POSTED` (no "Closed" state — that belongs to the separate, unbuilt Stock Pick module and must not be conflated with it). Variance is confirmed signed, not absolute — `StockCountServiceImpl.java:211` reads `varQty > 0 ? "IN" : "OUT"` — so `totalVarQty` genuinely distinguishes surplus from shortage, not just "off by some amount."

## Scope

Four changes to the existing Stock Count feature, all additive to what's already built:
1. A warehouse-picker bottom sheet gating "New Stock Count" creation, replacing the form's inline warehouse selector, with the last-used warehouse remembered locally.
2. Status + Warehouse filter dropdowns on the list page, both backed by real, confirmed backend params.
3. Visual redesign of the list card and detail page to match the brand styling already established for Login and Product Catalog, including extracting a shared info-card component now used by both Product Detail and this feature.
4. Pull-to-refresh on the list.

**Explicitly out of scope:**
- **The separate Stock Pick module** — confirmed with the user this request is about Stock Count, not Stock Pick (still "Coming soon", unbuilt, a different feature entirely).
- **Free-text search** — the backend has no free-text search param on this endpoint; only `status` and `warehouse` are real filters.
- **Client-controllable sort** — the backend hardcodes `stockcntId` descending server-side; no sort param exists to expose.
- **Approve/Post UI** — unchanged from the foundation spec's original decision: no permission check exists server-side for approve (hardcodes `"SYSTEM"` as approver), so mobile still doesn't add it.
- **Date formatting for `dateUpdated`** — stays a raw string display, matching current behavior; not part of what was asked.
- **Searchable/filterable warehouse picker** — no data suggesting this deployment has enough warehouses (30+) to need it; a plain list is adequate today. Revisit if a real customer hits that scale.
- **Icons on status chips** — the equivalent existing chip (`ProductBadge`) has no icons, color+label only. Adding icons only to the new stock-count chip would create a visual inconsistency between two chips doing the same job in the same app; if icons are worth adding, that's a coordinated pass across both, not a one-off here.
- **Header status-count summary** (e.g. "24 Open / 6 Approved / 130 Posted") — the search endpoint returns pagination for the current filtered query only, not a breakdown by status; would need 3 separate queries or a new backend aggregate endpoint. No such endpoint exists.

## Warehouse-picker bottom sheet

New `WarehousePickerSheet` (`lib/features/stock_count/presentation/widgets/warehouse_picker_sheet.dart`), shown via `showModalBottomSheet` when the list page's `+` icon is tapped (replacing the current direct `context.push('/stock-counts/new')`). A bottom sheet rather than a centered dialog: this is the first modal UI in the app (no existing dialog precedent to stay consistent with), and a bottom sheet is the more idiomatic mobile/Material 3 pattern for a one-handed "pick one, confirm" flow.

Reuses the existing `WarehouseSelector` widget (already a self-contained `DropdownButtonFormField<Warehouse>` with its own "Select a warehouse" validation) inside the sheet body. Loads warehouses via the existing `warehousesProvider(companyId)`. Default selection precedence: **last-remembered warehouse** (new — see below) if one exists, else the warehouse matching the user's branch (the existing default logic already in `StockCountFormPage._pickDefaultWarehouse`), else the first available warehouse. "Start Count" is disabled until a warehouse is selected; "Cancel" dismisses without navigating. On confirm: saves the selected warehouse as the new "last remembered" value, then navigates to `/stock-counts/new?whseCode={code}` — mirroring the router's existing query-param convention for this route (`companyId`/`branchId`/`stockcntId` are already passed this way for the edit path).

**Remembered warehouse**: new `RememberedWarehouseStorage` (`lib/core/storage/remembered_warehouse_storage.dart`), a SharedPreferences-backed class storing a single warehouse code — same single-purpose-file pattern as `RememberedUsernameStorage` from the login redesign, not a generalized "stock count preferences" bucket. Saved only on a successful "Start Count" confirmation (not on every dropdown change), read once when the sheet opens.

## Form page changes

`StockCountFormPage` drops its inline `WarehouseSelector` entirely, for both create and edit modes. The warehouse becomes a fixed, read-only line at the top of the form ("Warehouse: {code} · {description}") instead of an editable field:
- **Create mode**: the warehouse comes from the new `whseCode` route query parameter (set by the bottom sheet).
- **Edit mode**: the warehouse comes from the existing record being edited (`_existingWhseCode`, already fetched today) — unchanged in substance, just no longer editable. Real stock counts don't change physical location mid-count, so this isn't a behavior loss, just removing an edit capability that was never a deliberate feature (it existed only because the shared form's selector allowed it incidentally).

`StockCountFormPage` gains a new optional constructor parameter `whseCode` (used only when not editing); `WarehouseSelector` remains in the codebase, now consumed by `WarehousePickerSheet` instead of the form.

## List page: filters, empty state, pull-to-refresh

`StockCountSearchQuery` gains a `warehouse` field (nullable, alongside the existing `status`), threaded through `StockCountRepository.search()` → `SearchStockCountsUsecase` → `StockCountRemoteDatasource.search()` → the `warehouse` query param — mirroring exactly how `sortBy`/`sortDirection` were added to the Product repository chain.

Two dropdown chips above the list, matching the Product Catalog's dropdown-row pattern:
- **Status**: All / Open / Approved / Posted — the confirmed real lifecycle values, mapped to the exact backend strings (`OPEN`/`APPROVED`/`POSTED`); "All" sends no `status` param.
- **Warehouse**: All Warehouses + the loaded list (via `warehousesProvider`); "All Warehouses" sends no `warehouse` param.

Both filters re-query on change (no separate "Apply" step, consistent with how Product Catalog's dropdowns behave).

**Empty state**: kept deliberately minimal, matching the precedent just set on Product Catalog's `_EmptyResults` (icon + text, not a full illustration/description card) — but adds one thing that precedent didn't need: a "Create Stock Count" button that opens the same `WarehousePickerSheet` as the app bar `+`, since an empty list is exactly where a user needs that action most.

**Pull-to-refresh**: the list wraps in `RefreshIndicator`, calling the same refresh path as the existing error-state retry — mirrors what's already shipped on Product Catalog.

## Visual design — list card and detail page

**Status color convention** (new, stock-count-specific — not reusing `ProductBadge`, since the status vocabularies differ): Open → `AppColors.primary` (actively editable, matches the brand's "go" color), Approved → `AppColors.accent` (in progress toward posted), Posted → `AppColors.neutral` (final/archived state). A small `StockCountStatusChip` widget (`lib/features/stock_count/presentation/widgets/stock_count_status_chip.dart`) centralizes this label/color mapping, consumed by both the list card and the detail page's status banner — same "logic lives in exactly one place" pattern used for `ProductBadge`. Color + label only, no icons (see Explicitly out of scope).

**`StockCountCard`** (list item): rebuilt from a plain `ListTile` into a styled card (rounded corners, subtle shadow, matching `ProductCard`'s container treatment) showing the `StockCountStatusChip`, warehouse code, item count, and the variance quantity — colored by sign: `AppColors.primary`-toned green for a positive variance (surplus), `AppColors.danger` for negative (shortage), normal text color at exactly zero.

**Shared `InfoSectionCard`**: `ProductDetailPage`'s private `_InfoCard` widget (title + list of label-value rows) is promoted to `lib/shared/widgets/info_section_card.dart` as `InfoSectionCard`, and `ProductDetailPage` is updated to use the shared version instead of its own private copy. This is a deliberate touch to already-shipped Product Detail code, justified because a second real consumer exists now (Stock Count Detail) — the same reasoning that argued against building a speculative generic `PagedListNotifier<T>` earlier (zero real second consumers) argues *for* this extraction (a real second consumer, right now).

**`StockCountDetailPage`**: the status banner switches from hardcoded `Colors.green`/generic outline colors to `StockCountStatusChip`'s convention. The plain `Text` rows (Warehouse / Last updated / Total variance) become a single `InfoSectionCard`, matching the pattern now shared with `ProductDetailPage`. Line items move from bare `ListTile` rows to lightly-styled rows (rounded background, clearer qty emphasis) — same data as today, no new fields.

## Testing

- New widget tests for `WarehousePickerSheet`: renders warehouse options, "Start Count" disabled with no selection, enabled once one is picked, confirms navigation with the selected warehouse's code in the query string, "Cancel" dismisses without navigating, pre-selects a remembered warehouse when one exists, falls back to branch-matching default when none exists.
- New unit tests for `RememberedWarehouseStorage`: save/read round-trip (mirrors `RememberedUsernameStorage`'s existing test pattern).
- Update `StockCountFormPage` tests: no inline warehouse field present; warehouse displays read-only from the `whseCode` param (create) or the existing record (edit); existing OPEN-status edit guard tests unaffected.
- Update `StockCountListPage` tests: Status and Warehouse dropdown changes re-query with the correct params; empty state shows a working "Create Stock Count" button; pull-to-refresh re-queries; existing error/data-state tests preserved.
- New tests for `StockCountRemoteDatasource`/`SearchStockCountsUsecase`: `warehouse` param passes through correctly, defaults to absent when not set (mirrors the existing `search_products_usecase_test.dart` pattern).
- New widget test for `StockCountStatusChip`: correct label/color per status value.
- New widget test for the promoted `InfoSectionCard`: renders title + rows correctly (generic, not product- or stock-count-specific).
- Update `ProductDetailPage` tests: still pass unmodified after switching to the shared `InfoSectionCard` (same rendered output, different source file).
- Update `StockCountCard`/`StockCountDetailPage` tests (or add them where missing) to assert the new visual elements render, including variance sign coloring (positive/negative/zero).

## Non-goals

No backend changes. No changes to the separate Stock Pick module. No free-text search, no client-controllable sort, no Approve/Post UI, no date-formatting changes, no searchable warehouse picker, no status-chip icons, no header status-count summary — all covered under Explicitly out of scope above. No changes to `ProductBadge`/`ProductImage` (a new, stock-count-specific status chip is used instead, since the domains don't share a vocabulary) beyond `ProductDetailPage`'s `_InfoCard` being promoted to the shared `InfoSectionCard`.
