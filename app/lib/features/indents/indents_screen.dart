// Admin "Indents" screen — every indent the outlets have submitted, newest
// first, filterable by DO. Click a row for the per-size breakdown.
import 'package:flutter/material.dart';
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

  void _show(Indent i) => showDialog<void>(
        context: context,
        builder: (_) => _IndentDetailDialog(indent: i),
      );

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

class _IndentDetailDialog extends StatelessWidget {
  final Indent indent;
  const _IndentDetailDialog({required this.indent});

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    TextStyle mono(bool b) =>
        AppTheme.mono(size: 13, weight: b ? FontWeight.w700 : FontWeight.w500);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(DT.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _codeChip(indent.doCode),
                  const SizedBox(width: DT.s8),
                  Expanded(
                    child: Text(
                      '${indent.doName} — ${_dateFmt.format(indent.indentDate)}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  _payChip(indent),
                ],
              ),
              const SizedBox(height: DT.s16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 40,
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Stock'), numeric: true),
                    DataColumn(label: Text('Filled'), numeric: true),
                    DataColumn(label: Text('Empty'), numeric: true),
                    DataColumn(label: Text('Rate'), numeric: true),
                    DataColumn(label: Text('Amount'), numeric: true),
                  ],
                  rows: [
                    for (final it in indent.items)
                      DataRow(cells: [
                        DataCell(Text('${it.sizeKg} kg')),
                        DataCell(Text('${it.stock}', style: mono(false))),
                        DataCell(Text('${it.filled}', style: mono(false))),
                        DataCell(Text('${it.empty}', style: mono(false))),
                        DataCell(Text(fmtINR(it.rate), style: mono(false))),
                        DataCell(Text(fmtINR(it.amount), style: mono(false))),
                      ]),
                    DataRow(color: WidgetStatePropertyAll(DT.surface2), cells: [
                      const DataCell(Text('Total', style: bold)),
                      DataCell(Text('${indent.totalStock}', style: mono(true))),
                      DataCell(Text('${indent.totalFilled}', style: mono(true))),
                      DataCell(Text('${indent.totalEmpty}', style: mono(true))),
                      const DataCell(SizedBox.shrink()),
                      DataCell(Text(fmtINR(indent.totalAmount), style: mono(true))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: DT.s12),
              _line('Payment done', fmtINR(indent.amountPaid), DT.ok700),
              _line('Baki', fmtINR(indent.balance),
                  indent.isPaid ? DT.ok700 : DT.err700),
              const SizedBox(height: DT.s16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
