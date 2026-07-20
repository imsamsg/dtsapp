import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/session_info_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    return AppPageScaffold(
      currentPath: '/dashboard',
      title: 'Home',
      body: RefreshIndicator(
        onRefresh: () => ref.read(authStateProvider.notifier).restoreSession(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GreetingHeader(firstName: session.firstName),
            const SizedBox(height: 16),
            SessionInfoCard(companyId: session.companyId, branchId: session.branchId, roleName: session.roleName),
            const SizedBox(height: 24),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            QuickActionsGrid(
              actions: [
                QuickAction(
                  icon: Icons.inventory_2_outlined,
                  label: 'Product Catalog',
                  onTap: () => context.go('/products'),
                ),
                QuickAction(
                  icon: Icons.fact_check_outlined,
                  label: 'Stock Count',
                  onTap: () => context.go('/stock-counts'),
                ),
                QuickAction(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan Barcode',
                  onTap: () => _scanFromDashboard(context, ref),
                ),
                QuickAction(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Stock Pick',
                  enabled: false,
                  onTap: () {},
                ),
                QuickAction(
                  icon: Icons.point_of_sale_outlined,
                  label: 'POS',
                  enabled: false,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanFromDashboard(BuildContext context, WidgetRef ref) async {
    final scanner = ref.read(barcodeScannerServiceProvider);
    final barcode = await scanner.scan(context);
    if (barcode != null && context.mounted) {
      context.push('/products');
    }
  }
}
