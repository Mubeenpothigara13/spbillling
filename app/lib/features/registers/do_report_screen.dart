// "DO's Report" for a DO-scoped login: how many cylinders it sold and to
// whom — every sale with its date, customer and product, plus whether S.P.
// Gas has billed it yet. S.P. Gas (global login) keeps the DO Register.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/io/web_download.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/do_sale.dart';
import '../../data/repositories/do_sale_repo.dart';
import '../auth/auth_controller.dart';
import 'do_register_screen.dart';

/// Route `/register/do` — picks the right screen for the current login.
class DoReportEntryScreen extends ConsumerWidget {
  const DoReportEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDo = ref.watch(authControllerProvider).doCode != null;
    return isDo ? const DoReportScreen() : const DoRegisterScreen();
  }
}

final _dateFmt = DateFormat('dd-MMM-yyyy');

class DoReportScreen extends ConsumerStatefulWidget {
  const DoReportScreen({super.key});

  @override
  ConsumerState<DoReportScreen> createState() => _DoReportScreenState();
}

class _DoReportScreenState extends ConsumerState<DoReportScreen> {
  bool _exporting = false;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  int _page = 1;
  late Future<DoSalePage> _sales;
  late Future<DoSaleSummary> _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ref.read(doSaleRepoProvider);
    _sales = repo.list(fromDate: _from, toDate: _to, page: _page);
    _summary = repo.summary(fromDate: _from, toDate: _to);
    setState(() {});
  }

  Future<void> _pick({required bool from}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null) return;
    _page = 1;
    if (from) {
      _from = d;
    } else {
      _to = d;
    }
    _load();
  }

  String _err(Object? e) => e is ApiError ? e.message : '$e';

  Future<void> _export(String format) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(doSaleRepoProvider).exportBytes(
            fromDate: _from,
            toDate: _to,
            format: format,
          );
      final from = DateFormat('yyyy-MM-dd').format(_from);
      final to = DateFormat('yyyy-MM-dd').format(_to);
      final ext = format == 'excel' ? 'xlsx' : 'pdf';
      final mime = format == 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'application/pdf';
      await downloadBytes(
        Uint8List.fromList(bytes), 'do-report-$from-to-$to.$ext', mime,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Downloaded do-report.$ext'),
        backgroundColor: DT.ok700,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Export failed: ${_err(e)}'),
        backgroundColor: DT.err700,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('From', style: TextStyle(color: DT.text2)),
              const SizedBox(width: DT.s8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_dateFmt.format(_from)),
                onPressed: () => _pick(from: true),
              ),
              const SizedBox(width: DT.s16),
              const Text('To', style: TextStyle(color: DT.text2)),
              const SizedBox(width: DT.s8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_dateFmt.format(_to)),
                onPressed: () => _pick(from: false),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.grid_on, size: 14),
                label: const Text('Excel'),
                onPressed: _exporting ? null : () => _export('excel'),
              ),
              const SizedBox(width: DT.s8),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                label: const Text('PDF'),
                onPressed: _exporting ? null : () => _export('pdf'),
              ),
            ],
          ),
          const SizedBox(height: DT.s16),
          FutureBuilder<DoSaleSummary>(
            future: _summary,
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) return const SizedBox(height: 28);
              return Wrap(
                spacing: DT.s8,
                runSpacing: DT.s8,
                children: [
                  _pill('Total sold  ${s.totalQty}', DT.brand50, DT.brand800),
                  _pill('Customers  ${s.customerCount}', DT.surface3, DT.text),
                  for (final v in s.byVariant)
                    _pill('${v.variantName}  ${v.qty}', DT.surface3, DT.text),
                ],
              );
            },
          ),
          const SizedBox(height: DT.s16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.border),
              ),
              child: FutureBuilder<DoSalePage>(
                future: _sales,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(_err(snap.error),
                          style: const TextStyle(color: DT.err700)),
                    );
                  }
                  final page = snap.data!;
                  if (page.items.isEmpty) {
                    return const Center(
                      child: Text('No sales in this date range.',
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
                                '${page.total} sales · page ${page.page} of ${page.lastPage}',
                                style: const TextStyle(
                                    color: DT.text2, fontSize: DT.fsSm)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              onPressed: page.page > 1
                                  ? () {
                                      _page--;
                                      _load();
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              onPressed: page.page < page.lastPage
                                  ? () {
                                      _page++;
                                      _load();
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

  Widget _table(List<DoSale> rows) => DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: DT.rowHeight,
        dataRowMaxHeight: DT.rowHeight,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Mobile')),
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(_dateFmt.format(r.saleDate))),
              DataCell(Text(r.customerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(r.customerMobile?.isNotEmpty == true
                  ? r.customerMobile!
                  : '—')),
              DataCell(Text(r.variantName)),
              DataCell(Text('${r.quantity}', style: AppTheme.mono(size: 13))),
              DataCell(_statusChip(r.isBilled)),
            ]),
        ],
      );

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: DT.s12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DT.rXs),
        ),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: DT.fsSm, fontWeight: FontWeight.w600)),
      );

  Widget _statusChip(bool billed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
        decoration: BoxDecoration(
          color: billed ? DT.ok50 : DT.warn50,
          borderRadius: BorderRadius.circular(DT.rXs),
        ),
        child: Text(
          billed ? 'Billed' : 'Pending',
          style: TextStyle(
            color: billed ? DT.ok700 : DT.warn700,
            fontSize: DT.fsSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
