// Admin "DO Sales" screen — the sale lines Distributor Outlets have
// recorded. A DO doesn't bill: S.P. Gas turns each customer's pending lines
// (same customer + same day) into a bill via "Create bill", which opens
// New Bill pre-filled.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/bill.dart';
import '../../data/models/distributor_outlet.dart';
import '../../data/models/do_sale.dart';
import '../../data/repositories/do_sale_repo.dart';
import '../customers/customer_form_dialog.dart' show DOTypeahead;

final _dateFmt = DateFormat('dd-MMM-yyyy');

/// Route `/do-sales`.
class DoSalesScreen extends ConsumerStatefulWidget {
  const DoSalesScreen({super.key});

  @override
  ConsumerState<DoSalesScreen> createState() => _DoSalesScreenState();
}

class _DoSalesScreenState extends ConsumerState<DoSalesScreen> {
  String _status = 'pending';
  int? _doId;
  int _page = 1;
  bool _busy = false;
  late Future<DoSalePage> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<DoSalePage> _fetch() => ref
      .read(doSaleRepoProvider)
      .list(status: _status, doId: _doId, page: _page);

  void _reload() => setState(() => _future = _fetch());

  /// Opens New Bill with every pending line of this sale's customer on the
  /// same day (lines with the same product and rate are merged).
  Future<void> _createBill(DoSale sale) async {
    setState(() => _busy = true);
    try {
      final lines = await ref.read(doSaleRepoProvider).list(
            status: 'pending',
            customerId: sale.customerId,
            fromDate: sale.saleDate,
            toDate: sale.saleDate,
            perPage: 200,
          );
      final customer = await ref.read(customerRepoProvider).get(sale.customerId);
      final merged = <String, BillItemDraft>{};
      for (final l in lines.items) {
        final d = merged.putIfAbsent(
          '${l.variantId}|${l.rate}',
          () => BillItemDraft(
            variantId: l.variantId,
            variantLabel: l.variantName,
            quantity: 0,
            rate: l.rate,
            gstRate: l.gstRate,
          ),
        );
        d.quantity += l.quantity;
        d.emptyReturned += l.emptyReturned;
      }
      ref.read(pendingDoBillProvider.notifier).state = DoBillPrefill(
        customer: customer,
        billDate: sale.saleDate,
        items: merged.values.toList(),
        doSaleIds: [for (final l in lines.items) l.id],
      );
      if (mounted) context.go('/bills/new');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiError ? e.message : '$e'),
        backgroundColor: DT.err700,
      ));
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 380,
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
              const SizedBox(width: DT.s16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('Pending')),
                  ButtonSegment(value: 'billed', label: Text('Billed')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_status},
                onSelectionChanged: (s) {
                  _status = s.first;
                  _page = 1;
                  _reload();
                },
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
              child: FutureBuilder<DoSalePage>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    final e = snap.error;
                    return Center(
                      child: Text(e is ApiError ? e.message : '$e',
                          style: const TextStyle(color: DT.err700)),
                    );
                  }
                  final page = snap.data!;
                  if (page.items.isEmpty) {
                    return Center(
                      child: Text(
                        _status == 'pending'
                            ? 'No pending DO sales — everything is billed.'
                            : 'No DO sales found.',
                        style: const TextStyle(color: DT.text2),
                      ),
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
                                '${page.total} lines · page ${page.page} of ${page.lastPage}',
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

  Widget _table(List<DoSale> rows) => DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: DT.rowHeight,
        dataRowMaxHeight: DT.rowHeight,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('DO')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Rate'), numeric: true),
          DataColumn(label: Text('Bill')),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(_dateFmt.format(r.saleDate))),
              DataCell(_codeChip(r.doCode)),
              DataCell(Text(r.customerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(r.variantName)),
              DataCell(Text('${r.quantity}', style: AppTheme.mono(size: 13))),
              DataCell(Text(fmtINR(r.rate), style: AppTheme.mono(size: 13))),
              DataCell(r.isBilled
                  ? Text(r.billNumber ?? 'Billed',
                      style: AppTheme.mono(size: 12, color: DT.ok700))
                  : ElevatedButton(
                      onPressed: _busy ? null : () => _createBill(r),
                      child: const Text('Create bill'),
                    )),
            ]),
        ],
      );

  Widget _codeChip(String code) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: DT.brand50,
          borderRadius: BorderRadius.circular(DT.rXs),
        ),
        child: Text(code,
            style: const TextStyle(
                color: DT.brand800,
                fontSize: DT.fsSm,
                fontWeight: FontWeight.w700)),
      );
}
