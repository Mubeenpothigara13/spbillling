// Indent models — mirror `/api/indents`.

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}

int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// One cylinder size on the DO's indent form: how many it has sold (stock)
/// and the price per cylinder used to work out the amount.
class IndentSize {
  final int sizeKg;
  final int stock;
  final double rate;
  IndentSize({required this.sizeKg, required this.stock, required this.rate});

  factory IndentSize.fromJson(Map<String, dynamic> j) => IndentSize(
        sizeKg: _asInt(j['size_kg']),
        stock: _asInt(j['stock']),
        rate: _asDouble(j['rate']),
      );
}

class IndentItem {
  final int sizeKg;
  final int stock;
  final int filled;
  final int empty;
  final double rate;
  final double amount;
  IndentItem({
    required this.sizeKg,
    required this.stock,
    required this.filled,
    required this.empty,
    required this.rate,
    required this.amount,
  });

  factory IndentItem.fromJson(Map<String, dynamic> j) => IndentItem(
        sizeKg: _asInt(j['size_kg']),
        stock: _asInt(j['stock']),
        filled: _asInt(j['filled']),
        empty: _asInt(j['empty']),
        rate: _asDouble(j['rate']),
        amount: _asDouble(j['amount']),
      );
}

class Indent {
  final int id;
  final int doId;
  final String doCode;
  final String doName;
  final DateTime indentDate;
  final int totalStock;
  final int totalFilled;
  final int totalEmpty;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String status; // pending | approved | rejected
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final List<IndentItem> items;

  Indent({
    required this.id,
    required this.doId,
    required this.doCode,
    required this.doName,
    required this.indentDate,
    required this.totalStock,
    required this.totalFilled,
    required this.totalEmpty,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    required this.status,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
    required this.items,
  });

  bool get isPaid => balance <= 0;
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory Indent.fromJson(Map<String, dynamic> j) => Indent(
        id: _asInt(j['id']),
        doId: _asInt(j['do_id']),
        doCode: j['do_code'] as String? ?? '',
        doName: j['do_name'] as String? ?? '',
        indentDate: DateTime.parse(j['indent_date'] as String),
        totalStock: _asInt(j['total_stock']),
        totalFilled: _asInt(j['total_filled']),
        totalEmpty: _asInt(j['total_empty']),
        totalAmount: _asDouble(j['total_amount']),
        amountPaid: _asDouble(j['amount_paid']),
        balance: _asDouble(j['balance']),
        status: j['status'] as String? ?? 'pending',
        reviewedByName: j['reviewed_by_name'] as String?,
        reviewedAt: j['reviewed_at'] == null
            ? null
            : DateTime.tryParse(j['reviewed_at'] as String),
        reviewNote: j['review_note'] as String?,
        items: (j['items'] as List? ?? [])
            .map((e) => IndentItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
