import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(currentPath: '/dashboard', title: 'Home', body: Center(child: Text('Dashboard')));
  }
}
