class Product {
  const Product({
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
    required this.productBarcode,
    required this.productTitle,
    required this.productBrand,
    required this.isEnabled,
    required this.priceWithGst,
    required this.priceWithoutGst,
    required this.cost,
    required this.uom,
    required this.qtyOnHand,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String productBarcode;
  final String productTitle;
  final String productBrand;
  final bool isEnabled;
  final double priceWithGst;
  final double priceWithoutGst;
  final double cost;
  final String uom;
  final double qtyOnHand;
}

class ProductSearchResult {
  const ProductSearchResult({required this.items, required this.totalElements, required this.totalPages});

  final List<Product> items;
  final int totalElements;
  final int totalPages;
}
