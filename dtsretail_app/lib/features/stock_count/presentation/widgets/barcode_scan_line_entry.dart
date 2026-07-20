import 'package:flutter/material.dart';
import '../../domain/entities/stock_count_line.dart';

class BarcodeScanLineEntry extends StatelessWidget {
  const BarcodeScanLineEntry({
    super.key,
    required this.lines,
    required this.onScanPressed,
    required this.onQtyChanged,
    required this.onRemove,
  });

  final List<StockCountLine> lines;
  final VoidCallback onScanPressed;
  final void Function(int index, double qty) onQtyChanged;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: onScanPressed,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan barcode to add line'),
          ),
        ),
        ...lines.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          return ListTile(
            key: ValueKey('${line.productTypeCode}_${line.productCode}'),
            title: Text(line.productTitle.isEmpty ? line.productCode : line.productTitle),
            subtitle: Text(line.productCode),
            trailing: SizedBox(
              width: 140,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: line.countQty.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      onChanged: (value) => onQtyChanged(index, double.tryParse(value) ?? line.countQty),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(index)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
