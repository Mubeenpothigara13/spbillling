// Application entry point for SP Gas Billing.
//
// Boots the Flutter app inside a Riverpod ProviderScope so every provider
// (auth, API client, repositories, router) is available to the whole widget
// tree, then mounts SpBillingApp which wires up routing and theming.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Main entry — wraps the app in a Riverpod scope.
void main() => runApp(const ProviderScope(child: SpBillingApp()));

/// Root widget of the application.
///
/// Uses [MaterialApp.router] because navigation is driven by `go_router`
/// (see [routerProvider]). The router also handles auth redirects, so this
/// widget stays intentionally thin.
class SpBillingApp extends ConsumerWidget {
  const SpBillingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SP Gas Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Router is a Riverpod provider so it can listen to auth state changes
      // and redirect to /login whenever the user is logged out.
      routerConfig: ref.watch(routerProvider),
    );
  }
}
