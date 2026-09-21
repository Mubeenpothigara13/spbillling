// Sale screen for a DO-scoped login.
//
// One row per sale (customer + variant + qty + rate). Any number of rows
// can be added and a single Save at the bottom writes them all — rows that
// share a customer are merged into one bill. No summary rail, no GST
// field: the variant's own GST rate is still sent so bill accounting stays
// correct. S.P. Gas (global login) keeps the full [NewBillScreen].
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/bill.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../auth/auth_controller.dart';
import '../customers/customer_form_dialog.dart';
import 'new_bill_screen.dart';

/// Route `/bills/new` — picks the right screen for the current login.
class SaleEntryScreen extends ConsumerWidget {
  const SaleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDo = ref.watch(authControllerProvider).doCode != null;
    return isDo ? const DoSaleScreen() : const NewBillScreen();
  }
}

class _SaleRow {
  final Key key = UniqueKey();
  Customer? customer;
  final BillItemDraft item;
  _SaleRow(this.item);
}

class DoSaleScreen extends ConsumerStatefulWidget {
  const DoSaleScreen({super.key});

  @override
  ConsumerState<DoSaleScreen> createState() => _DoSaleScreenState();
}

class _DoSaleScreenState extends ConsumerState<DoSaleScreen> {
  List<ProductVariant> _variants = [];
  bool _loading = true;
  final List<_SaleRow> _rows = [];
  DateTime _saleDate = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    try {
      final list = await ref
          .read(productRepoProvider)
          .listVariants(perPage: 100, active: true);
      if (!mounted) return;
      setState(() {
        _variants = list;
        _loading = false;
      });
      if (_rows.isEmpty) _addRow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Prefers a 15 kg cylinder (the common sale), then any cylinder, then
  /// whatever comes first.
  ProductVariant? _defaultVariant() {
    if (_variants.isEmpty) return null;
    for (final v in _variants) {
      final label = v.displayName.toLowerCase();
      if (label.contains('15') &&
          (label.contains('kg') || label.contains('cylinder'))) {
        return v;
      }
    }
    return _variants.firstWhere(
      (v) => v.displayName.toLowerCase().contains('cylinder'),
      orElse: () => _variants.first,
    );
  }

  BillItemDraft _draftFor(ProductVariant v) => BillItemDraft(
        variantId: v.id,
        variantLabel: v.displayName,
        quantity: 1,
        rate: v.unitPrice,
        gstRate: v.gstRate,
      );

  /// A new row starts on the same variant as the previous one — sales in a
  /// run are usually the same size.
  void _addRow() {
    ProductVariant? v;
    if (_rows.isNotEmpty) {
      final id = _rows.last.item.variantId;
      final match = _variants.where((x) => x.id == id);
      if (match.isNotEmpty) v = match.first;
    }
    v ??= _defaultVariant();
    if (v == null) return;
    setState(() => _rows.add(_SaleRow(_draftFor(v!))));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _saleDate = d);
  }

  /// Validates every row, then creates one cash, fully-paid bill per
  /// distinct customer. Rows already saved are dropped from the list, so a
  /// failure part-way leaves only the unsaved rows on screen.
  Future<void> _save() async {
    if (_rows.isEmpty) {
      setState(() => _error = 'Add at least one sale');
      return;
    }
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.customer == null) {
        setState(() => _error = 'Sale ${i + 1}: pick a customer');
        return;
      }
      if (r.item.quantity <= 0) {
        setState(() => _error = 'Sale ${i + 1}: quantity must be at least 1');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final byCustomer = <int, List<_SaleRow>>{};
    for (final r in _rows) {
      byCustomer.putIfAbsent(r.customer!.id, () => []).add(r);
    }
    final billNumbers = <String>[];
    try {
      for (final group in byCustomer.values) {
        final items = group.map((r) => r.item).toList();
        final total = items.fold<double>(0, (s, i) => s + i.lineTotal);
        final bill = await ref.read(billRepoProvider).create(
              customerId: group.first.customer!.id,
              billDate: _saleDate,
              items: items,
              discount: 0,
              amountPaid: total,
              paymentMode: 'cash',
            );
        billNumbers.add(bill.billNumber);
        if (mounted) setState(() => _rows.removeWhere(group.contains));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(billNumbers.length == 1
            ? 'Bill ${billNumbers.first} saved'
            : '${billNumbers.length} bills saved'),
        backgroundColor: DT.ok600,
        duration: const Duration(seconds: 3),
      ));
      setState(() => _saving = false);
      _addRow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = billNumbers.isEmpty
            ? e.toString()
            : 'Saved ${billNumbers.length} of ${byCustomer.length} — $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DT.s24),
      child: Container(
        padding: const EdgeInsets.all(DT.s16),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Sale', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(_saleDate.toIso8601String().split('T').first),
                  onPressed: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: DT.s12),
            for (final r in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: DT.s8),
                child: _SaleRowCard(
                  key: r.key,
                  row: r,
                  variants: _variants,
                  onRemove: () => setState(() => _rows.remove(r)),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _variants.isEmpty ? null : _addRow,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add customer'),
              ),
            ),
            if (_variants.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: DT.s8),
                child: Text('No active products. Ask S.P. Gas to add products.',
                    style: TextStyle(color: DT.warn700, fontSize: DT.fsSm)),
              ),
            if (_error != null) ...[
              const SizedBox(height: DT.s12),
              Container(
                padding: const EdgeInsets.all(DT.s8),
                color: DT.err50,
                child: Text(_error!,
                    style:
                        const TextStyle(color: DT.err700, fontSize: DT.fsSm)),
              ),
            ],
            const SizedBox(height: DT.s16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleRowCard extends ConsumerStatefulWidget {
  final _SaleRow row;
  final List<ProductVariant> variants;
  final VoidCallback onRemove;

  const _SaleRowCard({
    super.key,
    required this.row,
    required this.variants,
    required this.onRemove,
  });

  @override
  ConsumerState<_SaleRowCard> createState() => _SaleRowCardState();
}

class _SaleRowCardState extends ConsumerState<_SaleRowCard> {
  final _search = TextEditingController();
  late final TextEditingController _qty;
  late final TextEditingController _rate;
  late final TextEditingController _empty;
  Timer? _debounce;
  List<Customer> _results = [];
  bool _searched = false;
  String _lastQuery = '';

  BillItemDraft get _item => widget.row.item;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: _item.quantity.toString());
    _rate = TextEditingController(text: _item.rate.toStringAsFixed(2));
    _empty = TextEditingController(text: _item.emptyReturned.toString());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _qty.dispose();
    _rate.dispose();
    _empty.dispose();
    super.dispose();
  }

  bool get _returnable {
    final m = widget.variants.where((v) => v.id == _item.variantId);
    return m.isNotEmpty && (m.first.isReturnable ?? false);
  }

  String _label(Customer c) {
    final village = c.village;
    return '${c.name}${village?.isNotEmpty == true ? ' — $village' : ''}';
  }

  void _onSearchChanged(String v) {
    if (widget.row.customer != null) {
      setState(() => widget.row.customer = null);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = v.trim();
      if (q.isEmpty) {
        if (mounted) {
          setState(() {
            _results = [];
            _searched = false;
            _lastQuery = '';
          });
        }
        return;
      }
      try {
        final r = await ref.read(customerRepoProvider).search(q);
        if (mounted) {
          setState(() {
            _results = r.where((c) => c.status == 'active').toList();
            _searched = true;
            _lastQuery = q;
          });
        }
      } catch (_) {}
    });
  }

  void _pick(Customer c) {
    setState(() {
      widget.row.customer = c;
      _results = [];
      _searched = false;
      _search.text = _label(c);
    });
  }

  Future<void> _addNewCustomer() async {
    final digits = _lastQuery.replaceAll(RegExp(r'\D'), '');
    final prefillMobile = digits.length >= 10 ? digits.substring(0, 10) : null;
    final prefillName =
        (prefillMobile == null && _lastQuery.isNotEmpty) ? _lastQuery : null;
    final saved = await showDialog<Customer?>(
      context: context,
      builder: (_) => CustomerFormDialog(
        prefillName: prefillName,
        prefillMobile: prefillMobile,
      ),
    );
    if (saved != null && mounted) _pick(saved);
  }

  void _changeVariant(int id) {
    final v = widget.variants.firstWhere((x) => x.id == id);
    setState(() {
      _item.variantId = v.id;
      _item.variantLabel = v.displayName;
      _item.rate = v.unitPrice;
      _item.gstRate = v.gstRate;
      _rate.text = v.unitPrice.toStringAsFixed(2);
      if (!(v.isReturnable ?? false)) {
        _item.emptyReturned = 0;
        _empty.text = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.row.customer;
    return Container(
      padding: const EdgeInsets.all(DT.s12),
      decoration: BoxDecoration(
        color: DT.surface2,
        borderRadius: BorderRadius.circular(DT.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                    hintText: 'Search by name, mobile, or customer ID',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: DT.err600),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          if (customer == null && _searched && _lastQuery.isNotEmpty) ...[
            const SizedBox(height: DT.s8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: DT.surface,
                border: Border.all(color: DT.border),
                borderRadius: BorderRadius.circular(DT.rSm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_results.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final c = _results[i];
                          final cn = c.consumerNumber;
                          return ListTile(
                            dense: true,
                            title: Text(_label(c)),
                            subtitle: Text(
                              '${c.mobile ?? '—'}${cn?.isNotEmpty == true ? '  ·  $cn' : ''}',
                              style: AppTheme.mono(size: 11, color: DT.text2),
                            ),
                            onTap: () => _pick(c),
                          );
                        },
                      ),
                    ),
                  if (_results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(DT.s12),
                      child: Text('No customers match.',
                          style: TextStyle(color: DT.text2)),
                    ),
                  const Divider(height: 1, color: DT.divider),
                  InkWell(
                    onTap: _addNewCustomer,
                    child: Container(
                      padding: const EdgeInsets.all(DT.s12),
                      color: DT.brand50,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle,
                              size: 16, color: DT.brand700),
                          const SizedBox(width: DT.s8),
                          Expanded(
                            child: Text(
                              'Add new customer "$_lastQuery"',
                              style: const TextStyle(
                                  color: DT.brand800,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (customer != null)
            Padding(
              padding: const EdgeInsets.only(top: DT.s4),
              child: Text(
                '${customer.mobile ?? '—'}'
                '${customer.consumerNumber?.isNotEmpty == true ? '  ·  ${customer.consumerNumber}' : ''}'
                '  ·  Empty pending ${customer.emptyPending}',
                style: AppTheme.mono(size: 11, color: DT.text2),
              ),
            ),
          const SizedBox(height: DT.s8),
          Wrap(
            spacing: DT.s8,
            runSpacing: DT.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int>(
                  initialValue: _item.variantId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [
                    for (final v in widget.variants)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(v.displayName,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => v == null ? null : _changeVariant(v),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  onChanged: (v) =>
                      setState(() => _item.quantity = int.tryParse(v) ?? 0),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rate'),
                  onChanged: (v) =>
                      setState(() => _item.rate = double.tryParse(v) ?? 0),
                ),
              ),
              if (_returnable)
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _empty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Empty ret.'),
                    onChanged: (v) => setState(
                        () => _item.emptyReturned = int.tryParse(v) ?? 0),
                  ),
                ),
              Text('Total ${fmtINR(_item.lineTotal)}',
                  style: AppTheme.mono(size: 12, weight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
