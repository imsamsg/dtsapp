import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/domain/entities/auth_session.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../product/presentation/providers/product_providers.dart';
import '../../domain/entities/stock_count_line.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/barcode_scan_line_entry.dart';

class StockCountFormPage extends ConsumerStatefulWidget {
  const StockCountFormPage({super.key, this.companyId, this.branchId, this.stockcntId, this.whseCode});

  final String? companyId;
  final String? branchId;
  final String? stockcntId;

  /// The warehouse code for a NEW count, supplied by [WarehousePickerSheet]
  /// via the route's query parameter. Ignored when editing — an existing
  /// count's warehouse comes from the loaded record instead. Read-only in
  /// both cases; see [_warehouseCode].
  final String? whseCode;

  bool get isEditing => stockcntId != null;

  @override
  ConsumerState<StockCountFormPage> createState() => _StockCountFormPageState();
}

class _StockCountFormPageState extends ConsumerState<StockCountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final List<StockCountLine> _lines = [];
  bool _isSaving = false;
  String? _errorMessage;

  // --- Editing-only state -------------------------------------------------
  //
  // The backend has no concurrency control on stock-count updates and always
  // forces the count's status back to OPEN on every update (see
  // UpdateStockCountUsecase / stock_count_mapper.dart from Task 11). Since
  // there is no server-side guard, this form is the only thing standing
  // between the user and silently corrupting a count that is no longer OPEN
  // (e.g. already CLOSED or POSTED). We therefore:
  //   1. Fetch the count's status directly from the usecase (bypassing
  //      stockCountDetailProvider's cache) when the form loads, so we never
  //      act on a stale value the detail page happened to have cached.
  //   2. Block editing entirely (no form, no Save) if it is not OPEN.
  //   3. Re-check immediately before submitting, to narrow (not eliminate —
  //      that needs a backend fix, out of scope for v1) the window in which
  //      another user could have closed/posted the count while this form
  //      was open.
  bool _loadingExisting = false;
  bool _blockedNotOpen = false;
  String? _existingStatus;
  String? _existingWhseCode;
  String? _loadErrorMessage;

  /// The warehouse code that applies to this form: the existing record's
  /// warehouse when editing, otherwise the code the picker sheet supplied.
  String? get _warehouseCode => widget.isEditing ? _existingWhseCode : widget.whseCode;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingExisting = true;
      Future.microtask(_loadExisting);
    }
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loadingExisting = true;
      _loadErrorMessage = null;
    });
    try {
      final usecase = ref.read(getStockCountDetailUsecaseProvider);
      final existing = await usecase(
        companyId: widget.companyId!,
        branchId: widget.branchId!,
        stockcntId: widget.stockcntId!,
      );
      if (!mounted) return;

      if (!existing.isOpen) {
        setState(() {
          _blockedNotOpen = true;
          _existingStatus = existing.status;
          _loadingExisting = false;
        });
        return;
      }

      setState(() {
        _lines
          ..clear()
          ..addAll(existing.lines);
        _existingStatus = existing.status;
        _existingWhseCode = existing.whseCode;
        _loadingExisting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadErrorMessage = 'Could not load stock count: $error';
        _loadingExisting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    if (widget.isEditing && _loadingExisting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Stock Count')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isEditing && _loadErrorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Stock Count')),
        body: AppErrorView(message: _loadErrorMessage!, onRetry: _loadExisting),
      );
    }

    if (widget.isEditing && _blockedNotOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Stock Count')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'This count has already been ${_existingStatus ?? 'closed'} and can no longer be edited.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!widget.isEditing && widget.whseCode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Stock Count')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warehouse_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No warehouse was selected. Please start again from Stock Counts.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );
    }

    final warehousesAsync = ref.watch(warehousesProvider(session.companyId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Stock Count' : 'New Stock Count')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            warehousesAsync.when(
              data: (warehouses) {
                final code = _warehouseCode;
                final match = warehouses.where((w) => w.code == code);
                final label = match.isNotEmpty ? '${match.first.code} · ${match.first.description}' : (code ?? '');
                return Text('Warehouse: $label', style: Theme.of(context).textTheme.titleMedium);
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load warehouse info: $error'),
            ),
            const SizedBox(height: 16),
            BarcodeScanLineEntry(
              lines: _lines,
              onScanPressed: () => _scanAndAddLine(session.companyId),
              onQtyChanged: (index, qty) => setState(() {
                final line = _lines[index];
                _lines[index] = StockCountLine(
                  productCode: line.productCode,
                  productTypeCode: line.productTypeCode,
                  productTitle: line.productTitle,
                  priceWithGst: line.priceWithGst,
                  cost: line.cost,
                  countQty: qty,
                );
              }),
              onRemove: (index) => setState(() => _lines.removeAt(index)),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : () => _submit(session),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndAddLine(String companyId) async {
    final scanner = ref.read(barcodeScannerServiceProvider);
    final barcode = await scanner.scan(context);
    if (barcode == null) return;

    try {
      final result = await ref.read(searchProductsUsecaseProvider)(
        companyId: companyId,
        searchString: barcode,
        searchKey: 3,
        size: 1,
      );
      if (result.items.isEmpty) {
        setState(() => _errorMessage = 'No product found for barcode $barcode');
        return;
      }

      final product = result.items.first;
      setState(() {
        _errorMessage = null;
        final existingIndex = _lines.indexWhere(
          (line) => line.productTypeCode == product.productTypeCode && line.productCode == product.productCode,
        );
        if (existingIndex != -1) {
          final existing = _lines[existingIndex];
          _lines[existingIndex] = StockCountLine(
            productCode: existing.productCode,
            productTypeCode: existing.productTypeCode,
            productTitle: existing.productTitle,
            priceWithGst: existing.priceWithGst,
            cost: existing.cost,
            countQty: existing.countQty + 1,
          );
        } else {
          _lines.add(StockCountLine(
            productCode: product.productCode,
            productTypeCode: product.productTypeCode,
            productTitle: product.productTitle,
            priceWithGst: product.priceWithGst,
            cost: product.cost,
            countQty: 1,
          ));
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to look up product: $error');
    }
  }

  Future<void> _submit(AuthSession session) async {
    final formValid = _formKey.currentState?.validate() ?? true;
    if (!formValid) return;

    if (_lines.isEmpty) {
      setState(() => _errorMessage = 'Add at least one line to save this count.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEditing) {
        final usecase = ref.read(getStockCountDetailUsecaseProvider);
        final current = await usecase(
          companyId: session.companyId,
          branchId: session.branchId,
          stockcntId: widget.stockcntId!,
        );
        if (!current.isOpen) {
          if (!mounted) return;
          setState(() {
            _blockedNotOpen = true;
            _existingStatus = current.status;
          });
          return;
        }

        await ref.read(updateStockCountUsecaseProvider)(
          companyId: session.companyId,
          branchId: session.branchId,
          stockcntId: widget.stockcntId!,
          cntType: 'CNT',
          whseCode: _warehouseCode!,
          lines: _lines,
          userId: session.loginId,
        );
      } else {
        await ref.read(createStockCountUsecaseProvider)(
          companyId: session.companyId,
          branchId: session.branchId,
          cntType: 'CNT',
          whseCode: _warehouseCode!,
          lines: _lines,
          userId: session.loginId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = 'Failed to save: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
