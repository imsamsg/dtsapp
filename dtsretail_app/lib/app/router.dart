import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/presentation/pages/login_page.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/product/presentation/pages/product_detail_page.dart';
import '../features/product/presentation/pages/product_list_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/stock_count/presentation/pages/stock_count_detail_page.dart';
import '../features/stock_count/presentation/pages/stock_count_form_page.dart';
import '../features/stock_count/presentation/pages/stock_count_list_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState is AuthLoading) return null;
      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
      GoRoute(
        path: '/products',
        builder: (context, state) => ProductListPage(initialSearch: state.uri.queryParameters['barcode']),
        routes: [
          GoRoute(
            path: ':companyId/:productTypeCode/:productCode',
            builder: (context, state) => ProductDetailPage(
              companyId: state.pathParameters['companyId']!,
              productTypeCode: state.pathParameters['productTypeCode']!,
              productCode: state.pathParameters['productCode']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/stock-counts',
        builder: (context, state) => const StockCountListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => StockCountFormPage(
              companyId: state.uri.queryParameters['companyId'],
              branchId: state.uri.queryParameters['branchId'],
              stockcntId: state.uri.queryParameters['stockcntId'],
            ),
          ),
          GoRoute(
            path: ':companyId/:branchId/:stockcntId',
            builder: (context, state) => StockCountDetailPage(
              companyId: state.pathParameters['companyId']!,
              branchId: state.pathParameters['branchId']!,
              stockcntId: state.pathParameters['stockcntId']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
    ],
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen(authStateProvider, (previous, next) => notifyListeners());
  }
  final Ref _ref;
}
