// Application shell: sidebar + top bar + page content.
//
// Mounted by the ShellRoute so it survives across navigations between
// dashboard/customers/products/etc. Highlights the active sidebar
// entry by longest-prefix match against the current route.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/inr.dart';
import '../../core/theme/design_tokens.dart';
import '../auth/auth_controller.dart';

/// One row in the sidebar.
class _NavEntry {
  final String title;
  final IconData icon;
  final String path;
  const _NavEntry(this.title, this.icon, this.path);
}

const _globalEntries = [
  _NavEntry('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  _NavEntry('Customers', Icons.people_outline, '/customers'),
  _NavEntry('Distributor Outlets', Icons.store_outlined, '/outlets'),
  _NavEntry('Products', Icons.inventory_2_outlined, '/products'),
  _NavEntry('Bills', Icons.receipt_outlined, '/bills'),
  _NavEntry('New Bill', Icons.receipt_long_outlined, '/bills/new'),
  _NavEntry('Daily Register', Icons.calendar_month_outlined, '/register/daily'),
  _NavEntry('DO Register', Icons.assignment_outlined, '/register/do'),
  _NavEntry('DO Sales', Icons.storefront_outlined, '/do-sales'),
  _NavEntry('Indents', Icons.local_shipping_outlined, '/indents'),
  _NavEntry('Users', Icons.manage_accounts_outlined, '/users'),
];

// A DO-scoped login gets a deliberately short sidebar — just the handful
// of screens an outlet actually needs day to day. Paths reuse the same
// screens as the global nav (already DO-scoped server-side); only the
// label changes to match how the outlet thinks about the task.
const _doEntries = [
  _NavEntry('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  _NavEntry('Add Customer', Icons.person_add_outlined, '/customers'),
  _NavEntry('Sale', Icons.point_of_sale_outlined, '/bills/new'),
  _NavEntry('Indent', Icons.inventory_outlined, '/indent'),
  _NavEntry("DO's Report", Icons.assignment_outlined, '/register/do'),
];

/// Picks the sidebar entry set for the current login: the short DO list
/// for a DO-scoped login, or the full list (minus Users/Outlets unless
/// this is S.P. Gas itself) otherwise.
List<_NavEntry> _entriesFor(AuthState auth) {
  if (auth.doCode != null) return _doEntries;
  final isGlobalAdmin = auth.role == 'admin';
  const globalOnlyPaths = {'/users', '/outlets'};
  return _globalEntries
      .where((e) => !globalOnlyPaths.contains(e.path) || isGlobalAdmin)
      .toList();
}

/// Frames the current page with the persistent sidebar and top bar.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final entries = _entriesFor(auth);
    final path = GoRouterState.of(context).uri.path;
    // Match by longest prefix so `/bills/new` picks "New Bill" over "Bills".
    final matches = entries.where((e) => path == e.path || path.startsWith('${e.path}/'));
    final current = matches.isEmpty
        ? entries.first
        : matches.reduce((a, b) => a.path.length >= b.path.length ? a : b);
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentPath: path),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: current.title),
                const Divider(height: 1, color: DT.divider),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// True if [entryPath] is the most specific match for [currentPath].
///
/// Needed because `/bills/new` would otherwise also light up the `/bills`
/// entry — we only highlight the longest prefix.
bool _isActive(String entryPath, String currentPath, List<_NavEntry> entries) {
  if (currentPath == entryPath) return true;
  if (!currentPath.startsWith('${entryPath}/')) return false;
  // Only mark active if no longer entry matches.
  for (final other in entries) {
    if (other.path == entryPath) continue;
    if (other.path.length > entryPath.length &&
        (currentPath == other.path ||
            currentPath.startsWith('${other.path}/'))) {
      return false;
    }
  }
  return true;
}

class _Sidebar extends ConsumerWidget {
  final String currentPath;
  const _Sidebar({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final visibleEntries = _entriesFor(auth);
    return Container(
      width: DT.sidebarWidth,
      decoration: const BoxDecoration(
        color: DT.surface,
        border: Border(right: BorderSide(color: DT.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DT.s16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: DT.brand600,
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                  child: const Icon(Icons.local_gas_station,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: DT.s12),
                const Expanded(
                  child: Text(
                    'SP Gas Billing',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: DT.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DT.divider),
          const SizedBox(height: DT.s8),
          for (final e in visibleEntries)
            _NavTile(entry: e, active: _isActive(e.path, currentPath, visibleEntries)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(DT.s12),
            child: Text(
              'v1.0',
              style: TextStyle(color: DT.text3, fontSize: DT.fsSm),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavEntry entry;
  final bool active;
  const _NavTile({required this.entry, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(DT.rSm),
        onTap: () => context.go(entry.path),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: DT.s12),
          decoration: BoxDecoration(
            color: active ? DT.brand50 : Colors.transparent,
            borderRadius: BorderRadius.circular(DT.rSm),
          ),
          child: Row(
            children: [
              Icon(entry.icon,
                  size: 18, color: active ? DT.brand700 : DT.text2),
              const SizedBox(width: DT.s12),
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: DT.fsBody,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? DT.brand800 : DT.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.fullName ?? 'User';
    return Container(
      height: DT.topbarHeight,
      color: DT.surface,
      padding: const EdgeInsets.symmetric(horizontal: DT.s20),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DT.text,
            ),
          ),
          const Spacer(),
          if (auth.doCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: DT.s8, vertical: 2),
              decoration: BoxDecoration(
                color: DT.brand600,
                borderRadius: BorderRadius.circular(DT.rXs),
              ),
              child: Text(
                'DO ${auth.doCode}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: DT.fsSm,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: DT.s8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: DT.s8, vertical: 2),
            decoration: BoxDecoration(
              color: DT.brand50,
              borderRadius: BorderRadius.circular(DT.rXs),
            ),
            child: Text(
              auth.role ?? '—',
              style: const TextStyle(
                color: DT.brand800,
                fontSize: DT.fsSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: DT.s12),
          CircleAvatar(
            radius: 14,
            backgroundColor: DT.brand600,
            child: Text(
              initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: DT.s8),
          Text(name,
              style: const TextStyle(fontSize: DT.fsBody, color: DT.text)),
          const SizedBox(width: DT.s12),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, size: 18, color: DT.text2),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
