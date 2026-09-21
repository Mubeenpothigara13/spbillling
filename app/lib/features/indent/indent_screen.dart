// DO "Indent" screen — one row per cylinder size.
//
// Stock is the number of cylinders of that size this outlet has sold (from
// the DO-scoped product-sales report). Filled / Empty / Amount are entry
// cells for now — they aren't persisted anywhere yet.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

const _sizesKg = [4, 12, 15, 21];

final _kgPattern = RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false);

class IndentScreen extends ConsumerStatefulWidget {
  const IndentScreen({super.key});

  @override
  ConsumerState<IndentScreen> createState() => _IndentScreenState();
}

class _IndentScreenState extends ConsumerState<IndentScreen> {
  late final Future<Map<int, int>> _stock = _loadStock();
  final Map<int, List<TextEditingController>> _cells = {
    for (final kg in _sizesKg) kg: [for (var i = 0; i < 3; i++) TextEditingController()],
  };

  @override
  void dispose() {
    for (final row in _cells.values) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// Cylinders sold per size, all time. A variant counts toward a size when
  /// its name carries that exact weight (e.g. "Commercial 15kg" → 15).
  Future<Map<int, int>> _loadStock() async {
    final rows = await ref.read(reportRepoProvider).productSales(
          fromDate: DateTime(2000),
          toDate: DateTime.now().add(const Duration(days: 1)),
        );
    final stock = {for (final kg in _sizesKg) kg: 0};
    for (final r in rows) {
      final m = _kgPattern.firstMatch(r.variantName);
      if (m == null) continue;
      final kg = double.parse(m.group(1)!);
      if (stock.containsKey(kg.toInt()) && kg == kg.toInt()) {
        stock[kg.toInt()] = stock[kg.toInt()]! + r.qtySold;
      }
    }
    return stock;
  }

  Widget _entry(TextEditingController c, {bool decimal = false}) => SizedBox(
        width: 110,
        child: TextField(
          controller: c,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
          ],
          style: AppTheme.mono(size: 13),
          decoration: const InputDecoration(hintText: '0'),
        ),
      );

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
        child: FutureBuilder<Map<int, int>>(
          future: _stock,
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
            final stock = snap.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width -
                      DT.sidebarWidth -
                      DT.s48,
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Stock'), numeric: true),
                      DataColumn(label: Text('Filled Cylinder'), numeric: true),
                      DataColumn(label: Text('Empty Cylinder'), numeric: true),
                      DataColumn(label: Text('Amount'), numeric: true),
                    ],
                    rows: [
                      for (final kg in _sizesKg)
                        DataRow(cells: [
                          DataCell(Text('$kg kg',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))),
                          DataCell(Text('${stock[kg]}',
                              style: AppTheme.mono(
                                  size: 13, weight: FontWeight.w600))),
                          DataCell(_entry(_cells[kg]![0])),
                          DataCell(_entry(_cells[kg]![1])),
                          DataCell(_entry(_cells[kg]![2], decimal: true)),
                        ]),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
