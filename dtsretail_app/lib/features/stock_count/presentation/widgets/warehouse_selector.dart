import 'package:flutter/material.dart';
import '../../domain/entities/warehouse.dart';

class WarehouseSelector extends StatelessWidget {
  const WarehouseSelector({
    super.key,
    required this.warehouses,
    required this.selected,
    required this.onChanged,
  });

  final List<Warehouse> warehouses;
  final Warehouse? selected;
  final ValueChanged<Warehouse> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Warehouse>(
      decoration: const InputDecoration(labelText: 'Warehouse'),
      initialValue: selected,
      items: warehouses
          .map((w) => DropdownMenuItem(value: w, child: Text('${w.code} · ${w.description}')))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      validator: (value) => value == null ? 'Select a warehouse' : null,
    );
  }
}
