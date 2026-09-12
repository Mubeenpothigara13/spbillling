// User accounts screen — global-admin only (S.P. Gas). Lets the S.P. Gas
// admin create a login for each Distributor Outlet without touching the
// API directly: pick a DO, set a username/password, and that DO can sign
// in and only ever see its own data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/distributor_outlet.dart';
import '../../data/models/managed_user.dart';
import '../../data/repositories/user_repo.dart';
import '../auth/auth_controller.dart';
import '../customers/customer_form_dialog.dart' show DOTypeahead;

/// Route `/users`.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  Future<UserPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(userRepoProvider).list(perPage: 100);
    setState(() {});
  }

  Future<void> _openForm({ManagedUser? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _deactivate(ManagedUser u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Deactivate login?'),
        content: Text('${u.username} will no longer be able to sign in.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirm != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(userRepoProvider).deactivate(u.id);
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isGlobalAdmin = auth.role == 'admin' && auth.doCode == null;

    if (!isGlobalAdmin) {
      return const Center(
        child: Text(
          'Only S.P. Gas can manage user logins.',
          style: TextStyle(color: DT.text2),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Users',
                    style: TextStyle(
                        fontSize: DT.fsH1,
                        fontWeight: FontWeight.w700,
                        color: DT.text)),
              ),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add User'),
              ),
            ],
          ),
          const SizedBox(height: DT.s16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.border),
              ),
              child: FutureBuilder<UserPage>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(snap.error.toString(),
                          style: const TextStyle(color: DT.err700)),
                    );
                  }
                  final items = snap.data!.items;
                  if (items.isEmpty) {
                    return const Center(
                        child: Text('No users yet.',
                            style: TextStyle(color: DT.text2)));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width -
                              DT.sidebarWidth -
                              DT.s48),
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: DT.rowHeight,
                        dataRowMaxHeight: DT.rowHeight,
                        columns: const [
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Full Name')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('DO')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [
                          for (final u in items)
                            DataRow(cells: [
                              DataCell(Text(u.username)),
                              DataCell(Text(u.fullName)),
                              DataCell(Text(u.role)),
                              DataCell(Text(u.doId == null ? 'S.P. Gas (all)' : 'DO #${u.doId}')),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: DT.s8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: u.isActive ? DT.ok50 : DT.surface3,
                                  borderRadius: BorderRadius.circular(DT.rXs),
                                ),
                                child: Text(
                                  u.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: u.isActive ? DT.ok700 : DT.text2,
                                    fontSize: DT.fsSm,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    onPressed: () => _openForm(existing: u),
                                  ),
                                  IconButton(
                                    tooltip: 'Deactivate',
                                    icon: const Icon(Icons.block, size: 16, color: DT.err600),
                                    onPressed: u.isActive ? () => _deactivate(u) : null,
                                  ),
                                ],
                              )),
                            ]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFormDialog extends ConsumerStatefulWidget {
  final ManagedUser? existing;
  const _UserFormDialog({this.existing});

  @override
  ConsumerState<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late String _role;
  late bool _isActive;
  DistributorOutlet? _do;
  bool _doLoading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _username = TextEditingController(text: e?.username ?? '');
    _password = TextEditingController();
    _fullName = TextEditingController(text: e?.fullName ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _role = e?.role ?? 'billing_staff';
    _isActive = e?.isActive ?? true;
    if (e?.doId != null) {
      _doLoading = true;
      ref.read(doRepoProvider).get(e!.doId!).then((d) {
        if (mounted) setState(() { _do = d; _doLoading = false; });
      }).catchError((_) {
        if (mounted) setState(() => _doLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepoProvider);
      if (widget.existing == null) {
        await repo.create(
          username: _username.text.trim(),
          password: _password.text,
          fullName: _fullName.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          role: _role,
          doId: _do?.id,
        );
      } else {
        await repo.update(
          widget.existing!.id,
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          role: _role,
          isActive: _isActive,
          password: _password.text.isEmpty ? null : _password.text,
          doId: _do?.id,
          clearDoId: _do == null,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DT.s20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEdit ? 'Edit user' : 'Add user',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: DT.s16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(DT.s8),
                    color: DT.err50,
                    child: Text(_error!,
                        style: const TextStyle(color: DT.err700, fontSize: DT.fsSm)),
                  ),
                  const SizedBox(height: DT.s12),
                ],
                TextFormField(
                  controller: _username,
                  enabled: !isEdit,
                  decoration: const InputDecoration(labelText: 'Username *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: DT.s12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'New password (leave blank to keep)' : 'Password *',
                  ),
                  validator: (v) {
                    if (isEdit) return null;
                    return (v == null || v.length < 4) ? 'Min 4 characters' : null;
                  },
                ),
                const SizedBox(height: DT.s12),
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Full name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: DT.s12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
                const SizedBox(height: DT.s12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role *'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'billing_staff', child: Text('Billing Staff')),
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: DT.s12),
                if (_doLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DT.s8),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: DT.s8),
                        Text('Loading current outlet…',
                            style: TextStyle(color: DT.text2, fontSize: DT.fsSm)),
                      ],
                    ),
                  )
                else
                  DOTypeahead(
                    key: ValueKey('user-do-${_do?.id ?? 'none'}'),
                    initial: _do,
                    required: false,
                    label: 'Distributor Outlet (leave blank = S.P. Gas login)',
                    onChanged: (v) => setState(() => _do = v),
                  ),
                if (isEdit) ...[
                  const SizedBox(height: DT.s12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
                const SizedBox(height: DT.s20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: DT.s8),
                    ElevatedButton(
                      onPressed: (_saving || _doLoading) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
