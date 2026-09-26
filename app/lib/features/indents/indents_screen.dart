// Admin "Indents" screen — every indent the outlets have submitted, newest
// first, filterable by DO. Click a row to Approve, Reject, or Edit it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/distributor_outlet.dart';
import '../../data/models/indent.dart';
import '../../data/repositories/indent_repo.dart';
import '../customers/customer_form_dialog.dart' show DOTypeahead;

final _dateFmt = DateFormat('dd-MMM-yyyy');

/// Route `/indents`.
class IndentsScreen extends ConsumerStatefulWidget {
  const IndentsScreen({super.key});

  @override
  ConsumerState<IndentsScreen> createState() => _IndentsScreenState();
}

class _IndentsScreenState extends ConsumerState<IndentsScreen> {
  int _page = 1;
  int? _doId;
  late Future<IndentPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<IndentPage> _fetch() =>
      ref.read(indentRepoProvider).list(page: _page, doId: _doId);

  void _reload() => setState(() => _future = _fetch());

  Future<void> _show(Indent i) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _IndentDetailDialog(indent: i),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 420,
              child: DOTypeahead(
                label: 'Filter by distributor outlet',
                required: false,
                onChanged: (DistributorOutlet? o) {
                  _doId = o?.id;
                  _page = 1;
                  _reload();
                },
              ),
            ),
          ),
          const SizedBox(height: DT.s16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.border),
              ),
              child: FutureBuilder<IndentPage>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    final e = snap.error;
                    return Center(
                      child: Text(e is ApiError ? e.message : e.toString(),
                          style: const TextStyle(color: DT.err700)),
                    );
                  }
                  final page = snap.data!;
                  if (page.items.isEmpty) {
                    return const Center(
                      child: Text('No indents submitted yet.',
                          style: TextStyle(color: DT.text2)),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width -
                                    DT.sidebarWidth -
                                    DT.s48,
                              ),
                              child: _table(page.items),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: DT.divider),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DT.s16, vertical: DT.s8),
                        child: Row(
                          children: [
                            Text(
                                '${page.total} indents · page ${page.page} of ${page.lastPage}',
                                style: const TextStyle(
                                    color: DT.text2, fontSize: DT.fsSm)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              onPressed: page.page > 1
                                  ? () {
                                      _page--;
                                      _reload();
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              onPressed: page.page < page.lastPage
                                  ? () {
                                      _page++;
                                      _reload();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(List<Indent> rows) => DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 40,
        dataRowMinHeight: DT.rowHeight,
        dataRowMaxHeight: DT.rowHeight,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Distributor Outlet')),
          DataColumn(label: Text('Filled'), numeric: true),
          DataColumn(label: Text('Empty'), numeric: true),
          DataColumn(label: Text('Amount'), numeric: true),
          DataColumn(label: Text('Paid'), numeric: true),
          DataColumn(label: Text('Payment')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final i in rows)
            DataRow(
              onSelectChanged: (_) => _show(i),
              cells: [
                DataCell(Text(_dateFmt.format(i.indentDate))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _codeChip(i.doCode),
                    const SizedBox(width: DT.s8),
                    Text(i.doName),
                  ],
                )),
                DataCell(_num('${i.totalFilled}')),
                DataCell(_num('${i.totalEmpty}')),
                DataCell(_num(fmtINR(i.totalAmount))),
                DataCell(_num(fmtINR(i.amountPaid))),
                DataCell(_payChip(i)),
                DataCell(_statusChip(i.status)),
              ],
            ),
        ],
      );
}

Widget _num(String v) => Text(v, style: AppTheme.mono(size: 13));

Widget _codeChip(String code) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DT.brand50,
        borderRadius: BorderRadius.circular(DT.rXs),
      ),
      child: Text(code,
          style: const TextStyle(
              color: DT.brand800, fontSize: DT.fsSm, fontWeight: FontWeight.w700)),
    );

/// "Paid" (green) or "Baki ₹x" (amber) — always text, never colour alone.
Widget _payChip(Indent i) => Container(
      padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
      decoration: BoxDecoration(
        color: i.isPaid ? DT.ok50 : DT.warn50,
        borderRadius: BorderRadius.circular(DT.rXs),
      ),
      child: Text(
        i.isPaid ? 'Paid' : 'Baki ${fmtINR(i.balance)}',
        style: TextStyle(
          color: i.isPaid ? DT.ok700 : DT.warn700,
          fontSize: DT.fsSm,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

Widget _statusChip(String status) {
  final (bg, fg, label) = switch (status) {
    'approved' => (DT.ok50, DT.ok700, 'Approved'),
    'rejected' => (DT.err50, DT.err700, 'Rejected'),
    _ => (DT.warn50, DT.warn700, 'Pending'),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DT.rXs)),
    child: Text(label,
        style: TextStyle(color: fg, fontSize: DT.fsSm, fontWeight: FontWeight.w600)),
  );
}

class _IndentDetailDialog extends ConsumerStatefulWidget {
  final Indent indent;
  const _IndentDetailDialog({required this.indent});

  @override
  ConsumerState<_IndentDetailDialog> createState() => _IndentDetailDialogState();
}

class _IndentDetailDialogState extends ConsumerState<_IndentDetailDialog> {
  late Indent _indent = widget.indent;
  bool _editing = false;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  final Map<int, TextEditingController> _filled = {};
  final Map<int, TextEditingController> _empty = {};
  late final TextEditingController _paid =
      TextEditingController(text: _indent.amountPaid.toStringAsFixed(2));

  TextEditingController _filledCtrl(int kg) => _filled.putIfAbsent(
      kg,
      () => TextEditingController(
          text: _indent.items.firstWhere((i) => i.sizeKg == kg).filled.toString()));

  TextEditingController _emptyCtrl(int kg) => _empty.putIfAbsent(
      kg,
      () => TextEditingController(
          text: _indent.items.firstWhere((i) => i.sizeKg == kg).empty.toString()));

  @override
  void dispose() {
    for (final c in [..._filled.values, ..._empty.values, _paid]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text) ?? 0;

  double _editedTotal() => _indent.items.fold<double>(
      0, (s, it) => s + _n(_filledCtrl(it.sizeKg)) * it.rate);

  Future<void> _run(Future<Indent> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _indent = updated;
        _busy = false;
        _editing = false;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiError ? e.message : '$e';
      });
    }
  }

  Future<void> _approve() => _run(() => ref.read(indentRepoProvider).approve(_indent.id));

  Future<void> _reject() async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject indent?'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'DO ko dikhega ki kyun reject hua',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() =>
        ref.read(indentRepoProvider).reject(_indent.id, note: noteCtrl.text.trim()));
  }

  Future<void> _saveEdit() async {
    final total = _editedTotal();
    final paid = double.tryParse(_paid.text) ?? 0;
    if (paid > total) {
      setState(() => _error = 'Paid amount total se zyada nahi ho sakta');
      return;
    }
    await _run(() => ref.read(indentRepoProvider).update(
          _indent.id,
          filled: {for (final it in _indent.items) it.sizeKg: _n(_filledCtrl(it.sizeKg))},
          empty: {for (final it in _indent.items) it.sizeKg: _n(_emptyCtrl(it.sizeKg))},
          amountPaid: paid,
        ));
  }

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    TextStyle mono(bool b) =>
        AppTheme.mono(size: 13, weight: b ? FontWeight.w700 : FontWeight.w500);
    final i = _indent;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(DT.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _codeChip(i.doCode),
                    const SizedBox(width: DT.s8),
                    Expanded(
                      child: Text(
                        '${i.doName} — ${_dateFmt.format(i.indentDate)}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    _statusChip(i.status),
                    const SizedBox(width: DT.s8),
                    _payChip(i),
                  ],
                ),
                if (i.reviewedByName != null) ...[
                  const SizedBox(height: DT.s4),
                  Text(
                    '${i.isRejected ? "Rejected" : "Reviewed"} by ${i.reviewedByName}'
                    '${i.reviewNote?.isNotEmpty == true ? " — ${i.reviewNote}" : ""}',
                    style: const TextStyle(color: DT.text2, fontSize: DT.fsSm),
                  ),
                ],
                const SizedBox(height: DT.s16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Stock'), numeric: true),
                      DataColumn(label: Text('Filled'), numeric: true),
                      DataColumn(label: Text('Empty'), numeric: true),
                      DataColumn(label: Text('Rate'), numeric: true),
                      DataColumn(label: Text('Amount'), numeric: true),
                    ],
                    rows: [
                      for (final it in i.items)
                        DataRow(cells: [
                          DataCell(Text('${it.sizeKg} kg')),
                          DataCell(Text('${it.stock}', style: mono(false))),
                          DataCell(_editing
                              ? _editField(_filledCtrl(it.sizeKg))
                              : Text('${it.filled}', style: mono(false))),
                          DataCell(_editing
                              ? _editField(_emptyCtrl(it.sizeKg))
                              : Text('${it.empty}', style: mono(false))),
                          DataCell(Text(fmtINR(it.rate), style: mono(false))),
                          DataCell(Text(
                              fmtINR(_editing
                                  ? _n(_filledCtrl(it.sizeKg)) * it.rate
                                  : it.amount),
                              style: mono(false))),
                        ]),
                      DataRow(color: WidgetStatePropertyAll(DT.surface2), cells: [
                        const DataCell(Text('Total', style: bold)),
                        DataCell(Text('${i.totalStock}', style: mono(true))),
                        const DataCell(SizedBox.shrink()),
                        const DataCell(SizedBox.shrink()),
                        const DataCell(SizedBox.shrink()),
                        DataCell(Text(
                            fmtINR(_editing ? _editedTotal() : i.totalAmount),
                            style: mono(true))),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: DT.s12),
                if (_editing)
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _paid,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: AppTheme.mono(size: 13),
                      decoration: const InputDecoration(labelText: 'Payment done (₹)'),
                    ),
                  )
                else ...[
                  _line('Payment done', fmtINR(i.amountPaid), DT.ok700),
                  _line('Baki', fmtINR(i.balance), i.isPaid ? DT.ok700 : DT.err700),
                ],
                if (_error != null) ...[
                  const SizedBox(height: DT.s12),
                  Container(
                    padding: const EdgeInsets.all(DT.s8),
                    color: DT.err50,
                    child: Text(_error!,
                        style: const TextStyle(color: DT.err700, fontSize: DT.fsSm)),
                  ),
                ],
                const SizedBox(height: DT.s16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_editing) ...[
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _editing = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: DT.s8),
                      ElevatedButton(
                        onPressed: _busy ? null : _saveEdit,
                        child: const Text('Save'),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () => setState(() => _editing = true),
                        child: const Text('Edit'),
                      ),
                      const SizedBox(width: DT.s8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: DT.err600),
                        onPressed: _busy ? null : _reject,
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: DT.s8),
                      ElevatedButton(
                        onPressed: _busy ? null : _approve,
                        child: const Text('Approve'),
                      ),
                      const SizedBox(width: DT.s8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(_changed),
                        child: const Text('Close'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(TextEditingController c) => SizedBox(
        width: 70,
        child: TextField(
          controller: c,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
          style: AppTheme.mono(size: 13),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(isDense: true, hintText: '0'),
        ),
      );

  Widget _line(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: DT.text2)),
            const Spacer(),
            Text(value,
                style: AppTheme.mono(
                    size: 13, weight: FontWeight.w700, color: color)),
          ],
        ),
      );
}
