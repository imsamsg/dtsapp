import 'stock_count_line.dart';

class StockCount {
  const StockCount({
    required this.companyId,
    required this.branchId,
    required this.stockcntId,
    required this.cntType,
    required this.status,
    required this.stockcntDate,
    required this.whseCode,
    required this.totalItems,
    required this.totalCountQty,
    required this.totalVarQty,
    required this.dateUpdated,
    required this.lines,
  });

  final String companyId;
  final String branchId;
  final String stockcntId;
  final String cntType;
  final String status;
  final String stockcntDate;
  final String whseCode;
  final int totalItems;
  final double totalCountQty;
  final double totalVarQty;
  final String dateUpdated;
  final List<StockCountLine> lines;

  bool get isOpen => status == 'OPEN';
}

class StockCountSearchResult {
  const StockCountSearchResult({required this.items, required this.totalElements, required this.totalPages});

  final List<StockCount> items;
  final int totalElements;
  final int totalPages;
}
