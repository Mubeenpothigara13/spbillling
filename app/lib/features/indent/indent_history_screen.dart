// DO's own "Indent History" — every indent this outlet has submitted, with
// S.P. Gas's Approved/Rejected/Pending status and, if rejected, the reason.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/indent.dart';
import '../../data/repositories/indent_repo.dart';

final _dateFmt = DateFormat('dd-MMM-yyyy');

class IndentHistoryScreen extends ConsumerStatefulWidget {
  const IndentHistoryScreen({super.key});

  @override
  ConsumerState<IndentHistoryScreen> createState() => _IndentHistoryScreenState();
}

class _IndentHistoryScreenState extends ConsumerState<IndentHistoryScreen> {
  int _page = 1;
  late Future<IndentPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<IndentPage> _fetch() => ref.read(indentRepoProvider).list(page: _page);

  void _reload() => setState(() => _future = _fetch());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
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
                child: Text('Koi indent submit nahi hua abhi tak.',
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
                          style: const TextStyle(color: DT.text2, fontSize: DT.fsSm)),
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
    );
  }

  Widget _table(List<Indent> rows) => DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 40,
        dataRowMinHeight: DT.rowHeight,
        dataRowMaxHeight: DT.rowHeight,
        columns: const [
          DataColumn(label: Text('Date')),
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
              onSelectChanged: (_) => showDialog<void>(
                context: context,
                builder: (_) => _HistoryDetailDialog(indent: i),
              ),
              cells: [
                DataCell(Text(_dateFmt.format(i.indentDate))),
                DataCell(Text('${i.totalFilled}', style: AppTheme.mono(size: 13))),
                DataCell(Text('${i.totalEmpty}', style: AppTheme.mono(size: 13))),
                DataCell(Text(fmtINR(i.totalAmount), style: AppTheme.mono(size: 13))),
                DataCell(Text(fmtINR(i.amountPaid), style: AppTheme.mono(size: 13))),
                DataCell(_payChip(i)),
                DataCell(_statusChip(i.status)),
              ],
            ),
        ],
      );
}

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

class _HistoryDetailDialog extends StatelessWidget {
  final Indent indent;
  const _HistoryDetailDialog({required this.indent});

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    TextStyle mono(bool b) =>
        AppTheme.mono(size: 13, weight: b ? FontWeight.w700 : FontWeight.w500);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(DT.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateFmt.format(indent.indentDate),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  _statusChip(indent.status),
                ],
              ),
              if (indent.reviewedByName != null) ...[
                const SizedBox(height: DT.s4),
                Text(
                  '${indent.isRejected ? "Rejected" : "Reviewed"} by ${indent.reviewedByName}'
                  '${indent.reviewNote?.isNotEmpty == true ? " — ${indent.reviewNote}" : ""}',
                  style: TextStyle(
                    color: indent.isRejected ? DT.err700 : DT.text2,
                    fontSize: DT.fsSm,
                  ),
                ),
              ],
              const SizedBox(height: DT.s16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 40,
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Filled'), numeric: true),
                    DataColumn(label: Text('Empty'), numeric: true),
                    DataColumn(label: Text('Rate'), numeric: true),
                    DataColumn(label: Text('Amount'), numeric: true),
                  ],
                  rows: [
                    for (final it in indent.items)
                      DataRow(cells: [
                        DataCell(Text('${it.sizeKg} kg')),
                        DataCell(Text('${it.filled}', style: mono(false))),
                        DataCell(Text('${it.empty}', style: mono(false))),
                        DataCell(Text(fmtINR(it.rate), style: mono(false))),
                        DataCell(Text(fmtINR(it.amount), style: mono(false))),
                      ]),
                    DataRow(color: WidgetStatePropertyAll(DT.surface2), cells: [
                      const DataCell(Text('Total', style: bold)),
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
