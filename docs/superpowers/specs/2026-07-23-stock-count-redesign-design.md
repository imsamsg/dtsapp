# dtsretail-app: Stock Count Redesign

## Context

`StockCountListPage`, `StockCountDetailPage`, and `StockCountFormPage` currently ship with no visual styling beyond default Material widgets (plain `ListTile`s, hardcoded `Colors.green`, plain `Text` rows) and no list filtering — `StockCountSearchQuery` already carries a `status` field but the UI never sets it. "New Stock Count" navigates straight from the list's `+` icon into the full form, which has an inline `WarehouseSelector` at the top.

While scoping this, the real backend `StockCountController.search` (`D:\Backend\dtsapi\...\StockCountController.java:29-37`) was checked directly: it accepts `companyId`, `branchId`, `status`, `warehouse`, `page`, `size` — the `warehouse` filter param exists server-side but was never plumbed through the Flutter datasource. Sort is hardcoded server-side (`stockcntId` descending) — not client-controllable, unlike Product's `sortBy`. The real status lifecycle was confirmed against `StockCountServiceImpl.java`: stock counts move `OPEN` → `APPROVED` → `POSTED` (no "Closed" state — that belongs to the separate, unbuilt Stock Pick module and must not be conflated with it).

## Scope

Three changes to the existing Stock Count feature, all additive to what's already built:
1. A warehouse-picker popup gating "New Stock Count" creation, replacing the form's inline warehouse selector.
2. Status + Warehouse filter dropdowns on the list page, both backed by real, confirmed backend params.
3. Visual redesign of the list card and detail page to match the brand styling already established for Login and Product Catalog.

**Explicitly out of scope:**
- **The separate Stock Pick module** — confirmed with the user this request is about Stock Count, not Stock Pick (still "Coming soon", unbuilt, a different feature entirely).
- **Free-text search** — the backend has no free-text search param on this endpoint; only `status` and `warehouse` are real filters.
- **Client-controllable sort** — the backend hardcodes `stockcntId` descending server-side; no sort param exists to expose.
- **Approve/Post UI** — unchanged from the foundation spec's original decision: no permission check exists server-side for approve (hardcodes `"SYSTEM"` as approver), so mobile still doesn't add it.
- **Date formatting for `dateUpdated`** — stays a raw string display, matching current behavior; not part of what was asked.

## Warehouse-picker popup

New `WarehousePickerDialog` (`lib/features/stock_count/presentation/widgets/warehouse_picker_dialog.dart`), shown via `showDialog` when the list page's `+` icon is tapped (replacing the current direct `context.push('/stock-counts/new')`). Reuses the existing `WarehouseSelector` widget (already a self-contained `DropdownButtonFormField<Warehouse>` with its own "Select a warehouse" validation) inside the dialog body. Loads warehouses via the existing `warehousesProvider(companyId)`, pre-selects the one matching the user's branch (the same default logic already in `StockCountFormPage._pickDefaultWarehouse`, minus its edit-specific branch). "Start Count" is disabled until a warehouse is selected; "Cancel" dismisses without navigating. On confirm, navigates to `/stock-counts/new?whseCode={code}` — mirroring the router's existing query-param convention for this route (`companyId`/`branchId`/`stockcntId` are already passed this way for the edit path).

## Form page changes

`StockCountFormPage` drops its inline `WarehouseSelector` entirely, for both create and edit modes. The warehouse becomes a fixed, read-only line at the top of the form ("Warehouse: {code} · {description}") instead of an editable field:
- **Create mode**: the warehouse comes from the new `whseCode` route query parameter (set by the popup).
- **Edit mode**: the warehouse comes from the existing record being edited (`_existingWhseCode`, already fetched today) — unchanged in substance, just no longer editable. Real stock counts don't change physical location mid-count, so this isn't a behavior loss, just removing an edit capability that was never a deliberate feature (it existed only because the shared form's selector allowed it incidentally).

`StockCountFormPage` gains a new optional constructor parameter `whseCode` (used only when not editing); `WarehouseSelector` remains in the codebase, now consumed by `WarehousePickerDialog` instead of the form.

## List page: filters

`StockCountSearchQuery` gains a `warehouse` field (nullable, alongside the existing `status`), threaded through `StockCountRepository.search()` → `SearchStockCountsUsecase` → `StockCountRemoteDatasource.search()` → the `warehouse` query param — mirroring exactly how `sortBy`/`sortDirection` were added to the Product repository chain.

Two dropdown chips above the list, matching the Product Catalog's dropdown-row pattern:
- **Status**: All / Open / Approved / Posted — the confirmed real lifecycle values, mapped to the exact backend strings (`OPEN`/`APPROVED`/`POSTED`); "All" sends no `status` param.
- **Warehouse**: All Warehouses + the loaded list (via `warehousesProvider`); "All Warehouses" sends no `warehouse` param.

Both filters re-query on change (no separate "Apply" step, consistent with how Product Catalog's dropdowns behave).

## Visual design — list card and detail page

**Status color convention** (new, stock-count-specific — not reusing `ProductBadge`, since the status vocabularies differ): Open → `AppColors.primary` (actively editable, matches the brand's "go" color), Approved → `AppColors.accent` (in progress toward posted), Posted → `AppColors.neutral` (final/archived state). A small `StockCountStatusChip` widget (`lib/features/stock_count/presentation/widgets/stock_count_status_chip.dart`) centralizes this label/color mapping, consumed by both the list card and the detail page's status banner — same "logic lives in exactly one place" pattern used for `ProductBadge`.

**`StockCountCard`** (list item): rebuilt from a plain `ListTile` into a styled card (rounded corners, subtle shadow, matching `ProductCard`'s container treatment) showing the `StockCountStatusChip`, warehouse code, item count, and the variance quantity — highlighted in `AppColors.danger` when non-zero (a variance is the number a warehouse worker needs to notice at a glance), in normal text color when zero.

**`StockCountDetailPage`**: the status banner switches from hardcoded `Colors.green`/generic outline colors to `StockCountStatusChip`'s convention. The plain `Text` rows (Warehouse / Last updated / Total variance) become a single grouped info card, matching the Details/Pricing card pattern from `ProductDetailPage`. Line items move from bare `ListTile` rows to lightly-styled rows (rounded background, clearer qty emphasis) — same data as today, no new fields.

## Testing

- New widget tests for `WarehousePickerDialog`: renders warehouse options, "Start Count" disabled with no selection, enabled once one is picked, confirms navigation with the selected warehouse's code in the query string, "Cancel" dismisses without navigating.
- Update `StockCountFormPage` tests: no inline warehouse field present; warehouse displays read-only from the `whseCode` param (create) or the existing record (edit); existing OPEN-status edit guard tests unaffected.
- Update `StockCountListPage` tests: Status and Warehouse dropdown changes re-query with the correct params; existing empty/error/data-state tests preserved.
- New tests for `StockCountRemoteDatasource`/`SearchStockCountsUsecase`: `warehouse` param passes through correctly, defaults to absent when not set (mirrors the existing `search_products_usecase_test.dart` pattern).
- New widget test for `StockCountStatusChip`: correct label/color per status value.
- Update `StockCountCard`/`StockCountDetailPage` tests (or add them where missing) to assert the new visual elements render.

## Non-goals

No backend changes. No changes to the separate Stock Pick module. No free-text search, no client-controllable sort, no Approve/Post UI, no date-formatting changes — all covered under Explicitly out of scope above. No changes to `ProductBadge`/`ProductImage` (a new, stock-count-specific status chip is used instead, since the domains don't share a vocabulary).
