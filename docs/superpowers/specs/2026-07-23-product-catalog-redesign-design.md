# dtsretail-app: Product Catalog Redesign

## Context

`ProductListPage` and `ProductDetailPage` currently ship far below what the foundation spec originally scoped: a plain `TextField` + `ListTile` list with no debounce, no search-key selector (the field exists in the data layer but was never exposed in the UI), and no pagination UI at all (`page` is hardcoded to `0`). Neither page carries any of the brand styling introduced in the login redesign.

While scoping this redesign, the real backend `ProductDto` (`D:\Backend\dtsapi\src\main\java\com\dts\webapi\dto\ProductDto.java`) turned out to carry several fields the Flutter side silently discards: `prodImage` (a real, actively-used S3 image URL — confirmed via `ProductSearchIntegrationTest.java` asserting it's non-empty on search results, and its use across POS/Sales/Purchase Order), `discontinueYN` (a second status flag alongside `enableyn`), and `productReorderLevel`/`productSafetyStock` (real low-stock thresholds). `ProductController.searchProducts` (`D:\Backend\dtsapi\...\ProductController.java:37-66`) confirms the search endpoint only accepts `companyId`, `searchString`, `searchKey`, `page`, `size`, `sortBy`, `sortDirection` — no category/brand/status/stock/price/date/warehouse filter params — and `ProductService.searchProducts` (`D:\Backend\dtsapi\...\ProductService.java:49-50`) confirms `sortBy` is passed raw into `Sort.by(direction, sortBy)`, so it must be a real JPA entity field name; `productCode`, `productTitle`, and `productPriceWgst` are all confirmed present on the `Product` entity.

`designs/appdesign.png` (component library + small app-screen thumbnails) is the visual reference, alongside the existing `designs/login.png` (mislabeled — it's actually the product catalog/filters mockup, per the earlier login-redesign session).

## Scope

Redesign `ProductListPage` (grid layout, images, badges, search, sort, infinite scroll) and `ProductDetailPage` (hero image, badges, styled detail sections). Extend the product data layer only as far as needed to honestly back this UI — no backend changes.

**Explicitly out of scope:**
- **Filter panel / counted status tabs** (Categories, Brand, Status, Stock Status, Price Range, Date Added, Warehouse, "Active (68)" style tabs) — the search endpoint has no filter params beyond `searchString`/`searchKey`. Building this would mean either fetching-all-then-filtering client-side (breaks server-side pagination, misleading at real catalog scale) or inventing params the backend doesn't accept.
- **Cart/checkout icons** on product cards — a POS concern, not Product Catalog; still deferred per the foundation spec.
- **Edit button** on the detail page — this app is read-only for product master data per the foundation spec; unchanged here.
- **Multi-image carousel** — only one `prodImage` field exists per product; the mockup's dot-pagination under the hero image isn't backed by real data.
- **Image caching package** (e.g. `cached_network_image`) — plain `Image.network` is enough for a first pass; not adding a new dependency for this.

## Data layer changes

**`ProductDto`** (`lib/features/product/data/models/product_dto.dart`) gains four nullable fields matching the real backend DTO: `prodImage`, `discontinueYN`, `productReorderLevel`, `productSafetyStock`.

**`Product`** entity (`lib/features/product/domain/entities/product.dart`) gains `imageUrl` (String?), `isDiscontinued` (bool), `reorderLevel` (double?), plus two computed getters so "what counts as low stock" and "what counts as active" live in exactly one place, not duplicated across widgets:

```dart
enum ProductStatus { active, inactive, discontinued }
enum StockLevel { inStock, lowStock, outOfStock }

class Product {
  // ...existing fields, plus:
  final String? imageUrl;
  final bool isDiscontinued;
  final double? reorderLevel;

  ProductStatus get status {
    if (isDiscontinued) return ProductStatus.discontinued;
    if (!isEnabled) return ProductStatus.inactive;
    return ProductStatus.active;
  }

  StockLevel get stockLevel {
    if (qtyOnHand <= 0) return StockLevel.outOfStock;
    if (reorderLevel != null && qtyOnHand <= reorderLevel!) return StockLevel.lowStock;
    return StockLevel.inStock;
  }
}
```

If `reorderLevel` is null, a product is simply never flagged "low stock" — no invented default threshold. Category badge uses the existing `productTypeCode` (e.g. "BOOK") — already present, no changes needed. `product_mapper.dart` updated accordingly; DTO isolation convention (mapper is the only place raw JSON touches the domain layer) is unchanged.

## Repository, sort, and pagination

`ProductRepository.search()` (interface, `ProductRepositoryImpl`, `SearchProductsUsecase`, `ProductRemoteDatasource`) gains optional `sortBy`/`sortDirection` params, defaulting to `'productCode'`/`'asc'` — matching the backend's own defaults, passed straight through to the query string.

The current single-page `productSearchProvider` (`FutureProvider.family<ProductSearchResult, ProductSearchQuery>`) is replaced by a `StateNotifier`-backed infinite-list controller:

```dart
class ProductListQuery {
  const ProductListQuery({
    required this.companyId,
    required this.searchString,
    this.searchKey = 0,
    this.sortBy = 'productCode',
    this.sortDirection = 'asc',
  });
  // == / hashCode over all five fields — page is NOT part of the key,
  // it's the notifier's own internal state.
}

class ProductListState {
  const ProductListState({
    this.items = const [],
    this.isLoading = false,   // initial / full reload
    this.isLoadingMore = false, // fetching page N+1
    this.hasMore = true,
    this.error,
    this.page = 0,
  });
  final List<Product> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final int page;
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  // constructor kicks off the first page load (page 0)
  Future<void> loadMore();  // no-ops if !hasMore || isLoadingMore
  Future<void> refresh();   // re-fetches page 0, replaces items (retry / sort change / search change)
}

final productListProvider = StateNotifierProvider.family<ProductListNotifier, ProductListState, ProductListQuery>(...);
```

`hasMore` is derived from `page + 1 < totalPages` on the last response. `loadMore()` fetches the next page and appends to `items`; `refresh()` replaces `items` entirely — used both for the explicit user-facing retry action and for pull-to-refresh (`RefreshIndicator` already an established pattern on `dashboard_page.dart`; this page reuses it, wrapping the grid, calling `refresh()` on pull).

Not part of this notifier's job, and already true today: search/sort state survives navigating to the detail page and back. Product detail is reached via `context.push` (not `.go`), so `ProductListPage` is never disposed while the detail page is on top of it — it's just obscured — and Riverpod's family-provider state is scoped to the `ProviderContainer`, not widget lifecycle. Confirmed by reading the current navigation call in `product_list_page.dart`; nothing new needed here.

## Search behavior

Debounced as-you-type search (~400ms) drives the query, via a `Timer?` that's explicitly cancelled and replaced on every keystroke — without the cancel, debouncing degrades into "fire once per keystroke after a delay" instead of "fire once after typing stops," which defeats the point. Pressing the keyboard's "done" action still submits immediately, cancelling any pending debounce timer and bypassing the wait — this preserves the exact interaction the existing tests already exercise (`enterText` + `TextInputAction.done` → immediate result), so those tests keep their trigger pattern; only the repository fake's method signature needs the two new optional params to satisfy the updated interface.

Search-key (Any/Code/Barcode/Title) and Sort (Code A-Z / Title A-Z / Title Z-A / Price Low-High / Price High-Low) become real dropdown chips feeding `ProductListQuery`, both backed by confirmed-real backend params.

## Visual design — ProductListPage

- **Search area**: rounded, icon-prefixed search field matching the login page's field style (leading search icon); barcode-scan icon retained in the `AppBar`. A row of two dropdown chips below it — Search key and Sort. Recent searches restyled as tappable chips (replacing the current plain `ListTile` rows).
- **Grid**: 2 columns, pull-to-refresh via `RefreshIndicator` wrapping it (calls `ProductListNotifier.refresh()`). Each card: square image area, `ClipRRect` + `BoxFit.cover` so images of any source aspect ratio present consistently with rounded corners matching the brand's rounded-corner language; `Image.network(imageUrl)` uses `frameBuilder` for a lightweight fade-in on load (not `FadeInImage`, which expects a placeholder *asset* we don't have) and a colored icon fallback by category when the URL is null/empty/fails to load. Two overlay chips — category (`productTypeCode`) top-left, stock-level top-right. Colors reuse `appdesign.png`'s previously-unused palette tokens: `#F59E0B` (amber) for Low Stock, existing `AppColors.danger` (`#EF4444`) for Out of Stock, brand green for In Stock. Below the image: title (2-line max, ellipsis), brand as a smaller subtitle, price prominent (`priceWithGst`) with cost shown smaller/secondary. A status chip (Inactive in slate `#64748B`, Discontinued in danger red) appears only when the product **isn't** Active — no badge clutter on the common case. Each card's image wrapped in `Hero(tag: '${product.companyId}-${product.productTypeCode}-${product.productCode}')` for a shared-element transition into the detail page.
- **Infinite scroll**: a dedicated `ScrollController` attached to the grid, with a listener that calls `loadMore()` once `position.pixels` nears `position.maxScrollExtent`; a small centered spinner row shows while `isLoadingMore`.
- **Empty state**: simple icon + "No products found" — kept as a small private widget in `product_list_page.dart`, not a new shared `AppEmptyState` abstraction (YAGNI — nothing else needs it yet).

## Visual design — ProductDetailPage

Large hero image at top, wrapped in the matching `Hero(tag: ...)` so it transitions from whichever card was tapped; same `ClipRRect`/`BoxFit.cover`/`frameBuilder` fade-in and fallback pattern as the grid card, just bigger. Title, brand subtitle, then the same category/status/stock badges as the grid card — reused via a shared `ProductBadges` widget (`lib/features/product/presentation/widgets/product_badges.dart`) consumed by both `ProductCard` and `ProductDetailPage`, so badge label/color logic exists in exactly one place. No edit icon. Below that, two grouped cards (matching the card language used throughout the app, rather than a flat list of rows): a **Details** card (Code, Barcode, UOM as label-value rows) and a **Pricing** card (Price incl. GST prominent, Price excl. GST + Cost secondary, Qty on hand plain). Loading/error states unchanged (`AppErrorView`).

## Testing

- Update `test/features/product/presentation/product_list_page_test.dart`: `_FakeProductRepository.search()` gains the two new optional params (compile-required by the interface change); existing four tests keep their current trigger patterns (`enterText` + `TextInputAction.done`, barcode scan, error display) and continue to pass against the new UI structure — `find.byType(TextField)` and `Icons.qr_code_scanner` stay valid anchors.
- New tests: grid renders a category/stock/status badge correctly per `Product.status`/`stockLevel` combination; image fallback renders the icon placeholder when `imageUrl` is null; sort dropdown changes the query's `sortBy`/`sortDirection`; `loadMore()` appends a second page and stops when `hasMore` is false; pulling to refresh calls `refresh()` and replaces (not appends to) `items`; debounce doesn't fire a search before the timer elapses, but "done" bypasses it and cancels the pending timer.
- New `test/features/product/presentation/product_detail_page_test.dart` (none exists today): loading/data/error states, badges render, no edit icon present.
- Unit tests for `ProductListNotifier` (page accumulation, `hasMore` derivation, refresh-replaces-not-appends) and for `Product.status`/`stockLevel` getters (all branch combinations, including `reorderLevel == null`).

## Non-goals

No backend changes. No changes to `AuthStateNotifier`, routing, or Stock Count. No filter panel, counted status tabs, cart icons, edit UI, multi-image carousel, or new image-caching dependency — all covered under Explicitly out of scope above.

**No generic `PagedListNotifier<T>` base class.** `ProductListNotifier` stays concrete. No other module (Purchase, Supplier, Customer, Notifications) is scoped anywhere in this project today, so a shared paging base would be an abstraction guessed from zero real second consumer — the same speculative-generalization pattern already declined twice during the login redesign (the `LoginPreferences` proposal), for the same reason. Extracting a shared base once a second module genuinely needs paging is a small, low-risk refactor informed by two real usages instead of one imagined one.
