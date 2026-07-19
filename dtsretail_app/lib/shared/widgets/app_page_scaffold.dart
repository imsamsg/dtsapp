import 'package:flutter/material.dart';
import 'app_drawer.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.currentPath,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String currentPath;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: AppDrawer(currentPath: currentPath),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
