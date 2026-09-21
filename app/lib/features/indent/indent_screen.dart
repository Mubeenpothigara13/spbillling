// DO "Indent" screen — one row per cylinder size, submitted to S.P. Gas.
//
// Stock = cylinders of that size this outlet has sold (server-computed).
// Filled can't exceed Stock; Empty is free. Amount = Filled x rate. Payment
// is a Paid amount with Baki (balance) worked out below the table.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/indent.dart';

/// Rejects an edit that would push the number above [max], so a value the
/// server would refuse can't be typed in the first place.
class _CapFormatter extends TextInputFormatter {
  final int max;
  final VoidCallback onExceed;
  _CapFormatter(this.max, this.onExceed);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next;
    final v = int.tryParse(next.text);
    if (v == null) return old;
    if (v > max) {
      onExceed();
      return old;
    }
    return next;
  }
}

class IndentScreen extends ConsumerStatefulWidget {
  const IndentScreen({super.key});

  @override
  ConsumerState<IndentScreen> createState() => _IndentScreenState();
}

class _IndentScreenState extends ConsumerState<IndentScreen> {
  late final Future<List<IndentSize>> _sizes =ref.read(indentRepoProvider).summary();
  final Map<int, TextEditingController> _filled = {};
  final Map<int, TextEditingController> _empty = {};
  final _paid = TextEditingController();
  bool _saving = false;
  String? _error;

  TextEditingController _ctrl(Map<int, TextEditingController> m, int kg) =>
      m.putIfAbsent(kg, TextEditingController.new);

  @override
  void dispose() {
    for (final c in [..._filled.values, ..._empty.values, _paid]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text) ?? 0;

  double _amount(IndentSize s) => _n(_ctrl(_filled, s.sizeKg)) * s.rate;

  Future<void> _submit(List<IndentSize> sizes) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(indentRepoProvider).submit(
            filled: {for (final s in sizes) s.sizeKg: _n(_ctrl(_filled, s.sizeKg))},
            empty: {for (final s in sizes) s.sizeKg: _n(_ctrl(_empty, s.sizeKg))},
            amountPaid: double.tryParse(_paid.text) ?? 0,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Indent submitted'),
        backgroundColor: DT.ok600,
        duration: Duration(seconds: 3),
      ));
      setState(() {
        _saving = false;
        for (final c in [..._filled.values, ..._empty.values, _paid]) {
          c.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiError ? e.message : e.toString();
      });
    }
  }

  void _tooMany(int kg, int stock) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text('$kg kg: Filled cylinders cannot be more than stock ($stock)'),
      backgroundColor: DT.err700,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _numField(TextEditingController c,
          {int? max, int kg = 0, bool decimal = false}) =>
      SizedBox(
        width: 110,
        child: TextField(
          controller: c,
          enabled: max == null || max > 0,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
            if (max != null) _CapFormatter(max, () => _tooMany(kg, max)),
          ],
          style: AppTheme.mono(size: 13),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '0'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<IndentSize>>(
      future: _sizes,
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
        return _content(snap.data!);
      },
    );
  }

  Widget _content(List<IndentSize> sizes) {
    final totalStock = sizes.fold<int>(0, (s, x) => s + x.stock);
    final totalFilled = sizes.fold<int>(0, (s, x) => s + _n(_ctrl(_filled, x.sizeKg)));
    final totalEmpty = sizes.fold<int>(0, (s, x) => s + _n(_ctrl(_empty, x.sizeKg)));
    final totalAmount = sizes.fold<double>(0, (s, x) => s + _amount(x));
    final paid = double.tryParse(_paid.text) ?? 0;
    final baki = totalAmount - paid;
    final overpaid = paid > totalAmount;
    const bold = TextStyle(fontWeight: FontWeight.w700);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: DT.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - DT.sidebarWidth - DT.s48,
                ),
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Stock'), numeric: true),
                    DataColumn(label: Text('Filled Cylinder'), numeric: true),
                    DataColumn(label: Text('Empty Cylinder'), numeric: true),
                    DataColumn(label: Text('Amount'), numeric: true),
                  ],
                  rows: [
                    for (final s in sizes)
                      DataRow(cells: [
                        DataCell(Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.sizeKg} kg',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              s.rate > 0 ? '${fmtINR(s.rate)} each' : 'Price not set',
                              style: TextStyle(
                                  fontSize: DT.fsSm,
                                  color: s.rate > 0 ? DT.text3 : DT.warn700),
                            ),
                          ],
                        )),
                        DataCell(Text('${s.stock}',
                            style: AppTheme.mono(size: 13, weight: FontWeight.w600))),
                        DataCell(_numField(_ctrl(_filled, s.sizeKg), max: s.stock, kg: s.sizeKg)),
                        DataCell(_numField(_ctrl(_empty, s.sizeKg))),
                        DataCell(Text(fmtINR(_amount(s)),
                            style: AppTheme.mono(size: 13, weight: FontWeight.w600))),
                      ]),
                    DataRow(color: WidgetStatePropertyAll(DT.surface2), cells: [
                      const DataCell(Text('Total', style: bold)),
                      DataCell(Text('$totalStock',
                          style: AppTheme.mono(size: 13, weight: FontWeight.w700))),
                      DataCell(Text('$totalFilled',
                          style: AppTheme.mono(size: 13, weight: FontWeight.w700))),
                      DataCell(Text('$totalEmpty',
                          style: AppTheme.mono(size: 13, weight: FontWeight.w700))),
                      DataCell(Text(fmtINR(totalAmount),
                          style: AppTheme.mono(size: 13, weight: FontWeight.w700))),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DT.s16),
          Container(
            padding: const EdgeInsets.all(DT.s16),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: DT.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Payment', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: DT.s12),
                Wrap(
                  spacing: DT.s12,
                  runSpacing: DT.s12,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _paid,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        style: AppTheme.mono(size: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Payment done (₹)',
                          hintText: '0',
                          errorText: overpaid ? 'More than total' : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Baki (₹)'),
                        child: Text(
                          fmtINR(overpaid ? 0 : baki),
                          style: AppTheme.mono(
                            size: 13,
                            weight: FontWeight.w700,
                            color: (!overpaid && baki > 0) ? DT.err700 : DT.ok700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: (_saving || overpaid) ? null : () => _submit(sizes),
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
                      label: const Text('Submit'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
