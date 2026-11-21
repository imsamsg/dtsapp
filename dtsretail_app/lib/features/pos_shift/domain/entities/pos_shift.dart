import 'pay_summary.dart';

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

  /// There is no standalone "total sales" field on the backend DTO — this
  /// matches exactly how the real reference app (dtsretail-inv) computes it:
  /// the sum of the payment-method breakdown.
  double get totalSales => paymentSummary.fold(0.0, (sum, p) => sum + p.totalAmount);
}
