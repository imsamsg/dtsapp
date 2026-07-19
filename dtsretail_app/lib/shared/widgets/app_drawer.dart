import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_theme.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'DTS Retail',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            _DrawerItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: currentPath == '/dashboard',
              onTap: () => _navigate(context, '/dashboard'),
            ),
            _DrawerItem(
              icon: Icons.inventory_2_outlined,
              label: 'Product',
              selected: currentPath.startsWith('/products'),
              onTap: () => _navigate(context, '/products'),
            ),
            _DrawerItem(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Stock Pick',
              selected: false,
              enabled: false,
              onTap: () {},
            ),
            _DrawerItem(
              icon: Icons.fact_check_outlined,
              label: 'Stock Count',
              selected: currentPath.startsWith('/stock-counts'),
              onTap: () => _navigate(context, '/stock-counts'),
            ),
            _DrawerItem(
              icon: Icons.point_of_sale_outlined,
              label: 'POS',
              selected: false,
              enabled: false,
              onTap: () {},
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: currentPath.startsWith('/settings'),
              onTap: () => _navigate(context, '/settings'),
            ),
            const Spacer(),
            const Divider(color: Colors.white24),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Logout',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authStateProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String path) {
    Navigator.of(context).pop();
    if (currentPath != path) context.go(path);
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled ? Colors.white38 : (selected ? Colors.white : Colors.white70);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Row(
        children: [
          Text(label, style: TextStyle(color: color)),
          if (!enabled) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
              child: const Text('Coming soon', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ),
          ],
        ],
      ),
      selected: selected,
      selectedTileColor: Colors.white12,
      onTap: enabled ? onTap : null,
    );
  }
}
