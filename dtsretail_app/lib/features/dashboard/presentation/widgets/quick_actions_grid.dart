import 'package:flutter/material.dart';

class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.onTap, this.enabled = true});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: actions
          .map((action) => Card(
                child: InkWell(
                  onTap: action.enabled ? action.onTap : null,
                  child: Opacity(
                    opacity: action.enabled ? 1 : 0.4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action.icon, size: 32),
                        const SizedBox(height: 8),
                        Text(action.label, textAlign: TextAlign.center),
                        if (!action.enabled) ...[
                          const SizedBox(height: 4),
                          Text('Coming soon', style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
