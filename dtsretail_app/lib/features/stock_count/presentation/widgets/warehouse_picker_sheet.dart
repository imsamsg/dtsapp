import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/remembered_warehouse_storage.dart';
import '../../domain/entities/warehouse.dart';
import '../providers/stock_count_providers.dart';
import 'warehouse_selector.dart';

class WarehousePickerSheet extends ConsumerStatefulWidget {
  const WarehousePickerSheet({super.key, required this.companyId, required this.branchId});

  final String companyId;
  final String branchId;

  @override
  ConsumerState<WarehousePickerSheet> createState() => _WarehousePickerSheetState();
}

class _WarehousePickerSheetState extends ConsumerState<WarehousePickerSheet> {
  Warehouse? _selected;

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehousesProvider(widget.companyId));
    final rememberedAsync = ref.watch(rememberedWarehouseStorageProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Select Warehouse', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 16),
          warehousesAsync.when(
            data: (warehouses) {
              _selected ??= _pickDefault(warehouses, rememberedAsync.asData?.value.read());
              return WarehouseSelector(
                warehouses: warehouses,
                selected: _selected,
                onChanged: (w) => setState(() => _selected = w),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (error, _) => Text('Could not load warehouses: $error'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selected == null ? null : _startCount,
                  child: const Text('Start Count'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Warehouse? _pickDefault(List<Warehouse> warehouses, String? rememberedCode) {
    if (warehouses.isEmpty) return null;
    if (rememberedCode != null) {
      for (final w in warehouses) {
        if (w.code == rememberedCode) return w;
      }
    }
    for (final w in warehouses) {
      if (w.branchCode == widget.branchId) return w;
    }
    return warehouses.first;
  }

  Future<void> _startCount() async {
    final selected = _selected!;
    final storage = await ref.read(rememberedWarehouseStorageProvider.future);
    await storage.save(selected.code);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    navigator.pop();
    router.push('/stock-counts/new?whseCode=${selected.code}');
  }
}
