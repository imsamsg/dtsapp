class StockCountLine {
  const StockCountLine({
    required this.productCode,
    required this.productTypeCode,
    required this.productTitle,
    required this.priceWithGst,
    required this.cost,
    required this.countQty,
  });

  final String productCode;
  final String productTypeCode;
  final String productTitle;
  final double priceWithGst;
  final double cost;
  final double countQty;
}
