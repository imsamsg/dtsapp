import 'package:flutter/material.dart';

class SessionInfoCard extends StatelessWidget {
  const SessionInfoCard({super.key, required this.companyId, required this.branchId, required this.roleName});

  final String companyId;
  final String branchId;
  final String roleName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _InfoColumn(label: 'Company', value: companyId),
            _InfoColumn(label: 'Branch', value: branchId),
            _InfoColumn(label: 'Role', value: roleName),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
