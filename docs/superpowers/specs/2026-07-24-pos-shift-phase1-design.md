# dtsretail-app: POS Shift Search & Detail (Phase 1)

## Context

The drawer (`app_drawer.dart`) and dashboard (`dashboard_page.dart`) both already have a "POS" entry, currently `enabled: false` with a "Coming soon" badge — the same treatment "Stock Pick" still has. This feature enables that entry and points it at a new POS Shift search + detail flow.

The backend (`D:\Backend\dtsapi`) already has a full, working API surface for this under `com.dts.webapi.pos`:
- `GET /api/v1/pos/posshifts` (`PosShiftController`) — search by `companyId`, `branchId`, optional `terminalId`, optional `fromDate`/`toDate` (ISO date). Returns the **entire** matching list in one response, wrapped in the standard `ApiResponse` envelope — **no `page`/`size` params exist**, and there is **no per-shift GET-by-id endpoint**. Sort is hardcoded server-side (`dateCreated DESC, shiftNo DESC`). Each `PosShiftDTO` already includes a payment-method breakdown (`lstPaySummDto`) — no extra call needed for that.
- `GET /api/v1/pos/terminals/branch/{companyId}/{branchId}` (`PosTerminalController`) — enabled terminals for a branch, returned as a **raw list** (not `ApiResponse`-wrapped, unlike the shift endpoint — same raw-vs-wrapped split that already exists between Product and Stock Count endpoints in this app).
- A further four endpoints (`/pos/trans`, `/pos/transdetail`, `/pos/hourly-sales`, `/pos/sales-by-category`) support a full transaction drill-down + charts dashboard, matching an existing, already-shipped reference implementation in the sibling Angular app `D:\Project\dtsretail-inv` (`pos-shifts` + `pos-shiftsales` components, with its own design spec at `dtsretail-inv/docs/superpowers/specs/2026-05-03-pos-shiftsales-design.md`). **These four endpoints and everything they'd power are out of scope for this spec** — see Phase 2 below.

The `dtsretail-inv` reference confirmed two important things: its "pagination" is actually client-side slicing of an already-fully-fetched array (the backend has no server pagination to page against), and its detail view never re-fetches — it reuses the already-loaded shift object from the list. Both patterns carry over here.

## Scope (Phase 1)

1. A POS Shift search/list page: Terminal + Date-range filters, immediate re-query on change, progressive reveal on scroll (no real pagination exists to page against).
2. A POS Shift detail page: per-shift KPI strip, payment summary, sales/drawer/transaction-metric breakdown — all sourced from the one already-fetched shift object, zero extra network calls.
3. Enabling the existing "POS" drawer and dashboard entries to navigate to the list page.

**Phase 2 (separate, future spec — not built now):** transaction drill-down list per shift, transaction detail (line items + payments), hourly sales chart, category breakdown pie chart. Needs `POSTransController`'s three remaining endpoints plus `POSSalesController`. Do not build any of this now; do not add empty scaffolding for it either (YAGNI — build it when its own spec exists).

**Explicitly out of scope for Phase 1:**
- Any of the Phase 2 items above.
- A list-page aggregate summary strip (e.g. "Today's Sales across all shifts"). Considered and declined: with the date filter able to span Today/7 Days/30 Days/Custom, a fixed "Today's" label would silently misrepresent whatever range is actually active. A correctly-labelled aggregate could be a later, separate addition.
- Editing or creating shifts — this is read-only reporting, unlike Stock Count.
- Skeleton-loader UI. This app has no skeleton-loading precedent anywhere (Login, Product, Stock Count all use a plain `CircularProgressIndicator` — confirmed directly in `product_list_page.dart:233,254`); introducing one here would be a new, unproven pattern for no stated need.

## Architecture

New `pos_shift` feature module, mirroring `stock_count`'s layering exactly:

```
lib/features/pos_shift/
  data/
    datasource/remote/pos_shift_remote_datasource.dart      (GET /pos/posshifts — ApiResponse-wrapped)
    datasource/remote/pos_terminal_remote_datasource.dart   (GET /pos/terminals/branch/{companyId}/{branchId} — raw list)
    mappers/pos_shift_mapper.dart, pos_terminal_mapper.dart
    models/pos_shift_dto.dart, pos_terminal_dto.dart, pay_summary_dto.dart
    repository/pos_shift_repository_impl.dart, pos_terminal_repository_impl.dart
  domain/
    entities/pos_shift.dart, pos_terminal.dart, pay_summary.dart
    repository/pos_shift_repository.dart, pos_terminal_repository.dart
    usecases/search_pos_shifts_usecase.dart, get_terminals_by_branch_usecase.dart
  presentation/
    providers/pos_shift_providers.dart
    pages/pos_shift_list_page.dart, pos_shift_detail_page.dart
    widgets/pos_shift_card.dart, pos_shift_status_chip.dart, pos_shift_kpi_strip.dart
```

`PosTerminal` gets its own small repository, the same way `Warehouse` does for Stock Count — it's reference/master data, not part of the shift search itself.

`PosShiftRepository` exposes exactly one method, mirroring the one real backend method — no `getDetail`/`getById`/`update`, since none of those exist server-side and none are needed (detail data comes from the already-fetched list item):

```dart
abstract interface class PosShiftRepository {
  Future<List<PosShift>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  });
}
```

### Domain entities

Only fields actually consumed by the UI are mapped (not the full ~50-field DTO — same discipline already applied to `Product`/`StockCount`):

```dart
class PosShift {
  const PosShift({
    required this.companyId,
    required this.branchId,
    required this.terminalId,
    required this.termName,
    required this.shiftNo,
    required this.shiftDateStr,
    required this.logOnDateTimeStr,
    required this.logOffDateTimeStr,
    required this.posOperatorId,
    required this.amountCash,
    required this.amountNonCash,
    required this.amountVariance,
    required this.openAmount,
    required this.cashInDraw,
    required this.cashCollected,
    required this.amountDrawn,
    required this.targetAmount,
    required this.totalGstAmount,
    required this.totalBills,
    required this.totalQty,
    required this.totalCost,
    required this.lineDelYN,
    required this.totalLineDel,
    required this.voidSaleYN,
    required this.totalVoidSale,
    required this.paymentSummary,
  });

  final String companyId;
  final String branchId;
  final String terminalId;
  final String? termName;
  final String shiftNo;
  final String shiftDateStr;
  final String? logOnDateTimeStr;
  final String? logOffDateTimeStr;
  final String? posOperatorId;
  final double amountCash;
  final double amountNonCash;
  final double amountVariance;
  final double openAmount;
  final double cashInDraw;
  final double cashCollected;
  final double amountDrawn;
  final double targetAmount;
  final double totalGstAmount;
  final int totalBills;
  final double totalQty;
  final double totalCost;
  final bool lineDelYN;
  final int totalLineDel;
  final bool voidSaleYN;
  final int totalVoidSale;
  final List<PaySummary> paymentSummary;

  /// A null/empty logoff timestamp means the shift is still active.
  bool get isOpen => logOffDateTimeStr == null || logOffDateTimeStr!.isEmpty;

  /// Total sales = sum of the payment-method breakdown, matching exactly
  /// how the real reference app (dtsretail-inv) computes it — there is no
  /// standalone "total sales" field on the backend DTO.
  double get totalSales => paymentSummary.fold(0.0, (sum, p) => sum + p.totalAmount);
}

class PaySummary {
  const PaySummary({required this.payMode, required this.totalAmount});
  final String payMode;
  final double totalAmount;
}

class PosTerminal {
  const PosTerminal({required this.terminalId, required this.displayName, required this.branchId});
  final String terminalId;
  final String displayName;
  final String branchId;
}
```

`PosTerminalMapper` builds `displayName` from the DTO's `displayName`, falling back to `terminalName`, then `terminalCode`, then the raw `terminalId` — mirroring the backend's own `mapToDTO`'s fallback chain for `termName` (`PosShiftServiceImpl.java:87-98`).

## List page

**Query object** (mirrors `StockCountSearchQuery`/`ProductListQuery` exactly — needed as the `family` provider key, not new ceremony):

```dart
enum DateRangePreset { today, last7Days, last30Days, custom }

class PosShiftSearchQuery {
  const PosShiftSearchQuery({
    required this.companyId,
    required this.branchId,
    this.terminalId,
    required this.fromDate,
    required this.toDate,
  });
  final String companyId;
  final String branchId;
  final String? terminalId;
  final DateTime fromDate;
  final DateTime toDate;
  // == / hashCode over all five fields
}
```

`DateRangePreset` is UI-only state (never serialized to the backend as a string — the query always carries resolved `fromDate`/`toDate`), so it stays a typed enum rather than a raw string, unlike backend-mirroring status strings elsewhere in this app.

**Filters row**, same shape as Stock Count's Status/Warehouse row:
- **Terminal** dropdown: "All Terminals" (sends no `terminalId`) + entries from `PosTerminalRepository`. Defaults to "All Terminals".
- **Date range** dropdown: Today (default) / 7 Days / 30 Days / Custom. Selecting Custom reveals two `showDatePicker` fields (From/To), each defaulting to the current `fromDate`/`toDate` when opened. An invalid range is prevented by construction rather than validated after the fact: the To picker's `firstDate` is bound to the selected From date, and the From picker's `lastDate` is bound to the selected To date, so a From-after-To selection is never reachable through the picker UI.

Both filters re-query immediately (no Search button), consistent with Product Catalog and Stock Count. On first open, before any filter is touched: **Today, All Terminals, auto-loaded** — no empty "waiting for search" state.

**Progressive reveal** (not real pagination — the backend returns everything matching the filter in one call; there is nothing further to fetch):

```dart
class PosShiftListState {
  const PosShiftListState({
    this.allItems = const [],
    this.visibleCount = 0,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });
  final List<PosShift> allItems;
  final int visibleCount;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  List<PosShift> get visibleItems => allItems.take(visibleCount).toList();
  bool get hasMoreVisible => visibleCount < allItems.length;
}

class PosShiftListNotifier extends StateNotifier<PosShiftListState> {
  static const _batchSize = 20;
  // On construction / filter change: fetch once via search(), set
  // allItems, set visibleCount = min(_batchSize, allItems.length).
  // loadMore(): visibleCount = min(visibleCount + _batchSize, allItems.length)
  //   — no network call, this is a synchronous reveal.
  // refresh(): re-runs search() for the current query (pull-to-refresh).
}
```

Initial reveal and each increment are both `20` — the same number already used as the default page size everywhere else in this app (`ProductListNotifier._pageSize`, every backend search default), rather than introducing a different number here.

**`PosShiftCard`**: terminal name + shift #, `PosShiftStatusChip` (Open → `AppColors.primary`, Closed → `AppColors.neutral`, derived from `PosShift.isOpen`), the shift date, and the variance amount colored **`!= 0 → AppColors.danger`, `== 0 → AppColors.neutral`** — deliberately different from Stock Count's signed surplus/shortage coloring, because for a cash drawer both overage and shortage warrant review; there's no "good" direction the way a stock surplus can be.

Pull-to-refresh re-runs the current filtered search. Empty state: receipt icon, "No shifts found", "Try another date range." (two lines, matching the existing empty-state shape used elsewhere but with an actionable second line).

## Detail page

No fetch, no loading state, no error state — the page renders exactly the `PosShift` object it was handed via navigation (see Routing below). Layout, top to bottom, all built from fields already on that one object:

1. **Header**: `PosShiftStatusChip` + `termName` (falls back to bare `terminalId` if null) + shift #.
2. **Metadata line**: Terminal ID · Operator (`posOperatorId`) · Date (`shiftDateStr`) · time range (`logOnDateTimeStr`–`logOffDateTimeStr`, or "–Open" while `isOpen`).
3. **`PosShiftKpiStrip`** (the one genuinely new widget here) — 4 values in a horizontal row: Total Sales (`PosShift.totalSales`), Cash (`amountCash`), Non-Cash (`amountNonCash`), Variance (`amountVariance`, same `!=0 → danger` coloring as the card).
4. **Payment Summary** — reuses the existing shared `InfoSectionCard` (title + label/value rows), not a new widget: one row per `paymentSummary` entry (`payMode` → formatted `totalAmount`), plus an appended "Total" row equal to `totalSales`. Fully dynamic — no assumed payment-mode set (Cash/Visa/etc. are backend data, not client-side constants).
5. **Sales Summary** (`InfoSectionCard`): Cash, Non-Cash, GST (`totalGstAmount`), Total (`totalSales`).
6. **Drawer Summary** (`InfoSectionCard`): Opening Amount (`openAmount`), Cash In Drawer (`cashInDraw`), Cash Collected (`cashCollected`), Amount Drawn (`amountDrawn`), Target (`targetAmount`).
7. **Transaction Metrics** (`InfoSectionCard`): Total Bills (`totalBills`), Total Qty (`totalQty`), Avg Bill Value (`totalCost / totalBills`, shown as `–` when `totalBills == 0`), and — only when the corresponding flag is true — Line Deletions (`totalLineDel`, shown iff `lineDelYN`) and Void Sales (`totalVoidSale`, shown iff `voidSaleYN`).

Note on "void count": the real web app gets this from a *live* `/pos/trans?status=V` query (a Phase 2 endpoint). What's shown here instead — `totalVoidSale` — is a denormalized summary count already present on this same shift DTO. Same information for the user, zero dependency on the deferred endpoint.

No FAB, no pull-to-refresh — nothing on this page is editable or re-fetchable.

## Menu integration & routing

**Router** (`router.dart`) — the shift object travels via GoRouter's `extra`, not a path/query param, since no URL can address a single shift server-side:

```dart
GoRoute(
  path: '/pos-shifts',
  builder: (context, state) => const PosShiftListPage(),
  routes: [
    GoRoute(
      path: 'detail',
      builder: (context, state) => PosShiftDetailPage(shift: state.extra as PosShift),
    ),
  ],
),
```

List page navigates with `context.push('/pos-shifts/detail', extra: shift)`. This is a deliberate, scoped deviation from this app's usual URL-addressable-detail convention (Product, Stock Count): there is no backend endpoint to deep-link against, so a URL-only route would either be unimplementable or would need a wasteful "re-fetch everything, find by shiftNo" workaround for no benefit. Opening this route without having navigated from the list (e.g. cold app start on this exact path) is not a supported flow, matching the equivalent real-world reference app's own behavior.

**Drawer** (`app_drawer.dart`): the existing "POS" `_DrawerItem` changes from `enabled: false` to `enabled: true`, `selected: currentPath.startsWith('/pos-shifts')`, `onTap: () => _navigate(context, '/pos-shifts')` — identical shape to the Stock Count entry directly above it.

**Dashboard** (`dashboard_page.dart`): the existing "POS" `QuickAction` drops `enabled: false` and gets `onTap: () => context.go('/pos-shifts')`.

**Existing test impact** (verified directly against the current file, not assumed): `dashboard_page_test.dart:64` currently asserts `expect(find.text('Coming soon'), findsNWidgets(2))` (Stock Pick + POS both disabled). Once POS is enabled this becomes `findsNWidgets(1)`, and the stale comment at `:56-58` (referencing "Task 7" from the original foundation plan) is updated to match. The separate `'tapping a disabled quick action does nothing'` test only exercises Stock Pick and needs no change. A new test is added alongside the existing `'Product Catalog and Stock Count tiles navigate via GoRouter'` test (`:92`), same router-harness shape, asserting the POS tile pushes to `/pos-shifts`.

## Testing

- **Unit**: `PosShiftMapper`/`PosTerminalMapper` (DTO→domain field mapping, including the terminal display-name fallback chain), `SearchPosShiftsUsecase`/`GetTerminalsByBranchUsecase` (param forwarding, null defaults), `PosShiftListNotifier` (initial fetch reveals 20; `loadMore()` reveals 20 more with no network call once all items are already fetched; `visibleCount` resets on filter/query change; `refresh()` re-fetches).
- **Widget**: `PosShiftStatusChip` (Open/Closed), `PosShiftCard` (status chip + variance coloring at `>0`/`<0`/`==0`), `PosShiftKpiStrip` (renders all 4 values, variance colored), `PosShiftListPage` (terminal/date-range filters re-query with correct params, progressive reveal triggers near scroll-bottom, pull-to-refresh, empty state, tapping a card pushes `/pos-shifts/detail` with the right `extra`), `PosShiftDetailPage` (renders all seven sections from a fixture shift; payment-summary rows proven dynamic by using a fixture with invented payment-mode names, not real ones like "Cash"/"Visa"; conditional Line Deletions/Void Sales rows appear only when their `YN` flag is true).
- **Dashboard**: update the existing `Coming soon` count assertion, add the POS-navigates test described above.

## Non-goals

No backend changes. No Phase 2 (transaction drill-down, transaction detail, hourly chart, category pie chart) — separate future spec. No list-page aggregate summary strip. No editing/creating shifts. No skeleton loaders. No changes to `ProductBadge`/`StockCountStatusChip` — POS Shift gets its own `PosShiftStatusChip` since Open/Closed is a different, simpler vocabulary than either existing chip's.
