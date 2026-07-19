import 'package:flutter/material.dart';

class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({super.key, required this.terms, required this.onSelected});

  final List<String> terms;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...terms.map(
          (term) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(term),
            onTap: () => onSelected(term),
          ),
        ),
      ],
    );
  }
}
