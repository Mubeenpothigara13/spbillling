import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/outlets/outlets_screen.dart';
import '../../features/newbill/new_bill_screen.dart';
import '../../features/bills/bill_pdf_screen.dart';
import '../../features/bills/bills_batch_pdf_screen.dart';
import '../../features/bills/bills_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListen = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => authListen.value++);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authListen,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.authenticated) return loggingIn ? null : '/login';
      if (auth.authenticated && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/bills/:id/pdf',
        builder: (_, s) => BillPdfScreen(billId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/bills/batch-print',
        builder: (_, s) {
          final qp = s.uri.queryParameters;
          final from = DateTime.parse(qp['from']!);
          final to = DateTime.parse(qp['to']!);
          final format = qp['format'] ?? '9up';
          final doId = int.tryParse(qp['do_id'] ?? '');
          final city = qp['city'];
          final bnFrom = qp['bill_number_from'];
          final bnTo = qp['bill_number_to'];
          return BillsBatchPdfScreen(
            fromDate: from,
            toDate: to,
            format: format,
            doId: doId,
            city: (city == null || city.isEmpty) ? null : city,
            billNumberFrom: (bnFrom == null || bnFrom.isEmpty) ? null : bnFrom,
            billNumberTo: (bnTo == null || bnTo.isEmpty) ? null : bnTo,
          );
        },
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/outlets', builder: (_, __) => const OutletsScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/bills', builder: (_, __) => const BillsScreen()),
          GoRoute(path: '/bills/new', builder: (_, __) => const NewBillScreen()),
        ],
      ),
    ],
  );
});
