enum ProductStatus { active, inactive, discontinued }

enum StockLevel { inStock, lowStock, outOfStock }

class Product {
  const Product({
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
    required this.productBarcode,
    required this.productTitle,
    required this.productBrand,
    required this.isEnabled,
    required this.isDiscontinued,
    required this.priceWithGst,
    required this.priceWithoutGst,
    required this.cost,
    required this.uom,
    required this.qtyOnHand,
    this.imageUrl,
    this.reorderLevel,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String productBarcode;
  final String productTitle;
  final String productBrand;
  final bool isEnabled;
  final bool isDiscontinued;
  final double priceWithGst;
  final double priceWithoutGst;
  final double cost;
  final String uom;
  final double qtyOnHand;
  final String? imageUrl;
  final double? reorderLevel;

  /// Stable per-product identity for [Hero] transitions between the grid
  /// card and the detail page.
  String get heroTag => 'product-image-$companyId-$productTypeCode-$productCode';

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

class ProductSearchResult {
  const ProductSearchResult({required this.items, required this.totalElements, required this.totalPages});

  final List<Product> items;
  final int totalElements;
  final int totalPages;
}
