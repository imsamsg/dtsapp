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
                    child: _QtyField(
                      qty: line.countQty,
                      onChanged: (qty) => onQtyChanged(index, qty),
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

/// Qty input for a single line. Because the containing `ListTile` is keyed
/// by product identity (not list index — see the `ValueKey` above), the same
/// row/field is reused when its `qty` changes programmatically (e.g. a
/// rescan merging into the existing line bumps `countQty`) rather than by
/// the user typing into it. `TextFormField`'s `initialValue` is only applied
/// once, in `initState` — a later change to `initialValue` on an already-
/// built field is silently ignored — so a plain `TextFormField` would keep
/// showing the pre-merge quantity until the user happened to touch the
/// field. This widget owns its `TextEditingController` and explicitly
/// re-syncs it in `didUpdateWidget` whenever `qty` changes externally, but
/// only while the field is unfocused, so it never clobbers text the user is
/// actively editing (during typing, `qty` and the controller's text are
/// already in agreement, so no sync is needed).
class _QtyField extends StatefulWidget {
  const _QtyField({required this.qty, required this.onChanged});

  final double qty;
  final ValueChanged<double> onChanged;

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _QtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.qty != oldWidget.qty && !_focusNode.hasFocus) {
      // Deferred to a post-frame callback: assigning to the controller's
      // text synchronously here would notify the TextFormField's internal
      // listener, which calls setState while this widget's ancestors (the
      // page's Form) are still mid-build, and Flutter forbids that
      // ("setState() or markNeedsBuild() called during build").
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _controller.text = widget.qty.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Qty'),
      onChanged: (value) => widget.onChanged(double.tryParse(value) ?? widget.qty),
    );
  }
}
