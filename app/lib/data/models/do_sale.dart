// DO sale models — mirror `/api/do-sales`.
import 'bill.dart';
import 'customer.dart';

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}

int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// One sale line recorded by a Distributor Outlet. `billId == null` means
/// S.P. Gas hasn't billed it yet.
class DoSale {
  final int id;
  final int doId;
  final String doCode;
  final int customerId;
  final String customerName;
  final String? customerVillage;
  final String? customerMobile;
  final DateTime saleDate;
  final int variantId;
  final String variantName;
  final int quantity;
  final double rate;
  final double gstRate;
  final int emptyReturned;
  final int? billId;
  final String? billNumber;

  DoSale({
    required this.id,
    required this.doId,
    required this.doCode,
    required this.customerId,
    required this.customerName,
    this.customerVillage,
    this.customerMobile,
    required this.saleDate,
    required this.variantId,
    required this.variantName,
    required this.quantity,
    required this.rate,
    required this.gstRate,
    required this.emptyReturned,
    this.billId,
    this.billNumber,
  });

  bool get isBilled => billId != null;

  /// "Name — Village" (village only when there is one).
  String get customerLabel => customerVillage?.isNotEmpty == true
      ? '$customerName — $customerVillage'
      : customerName;

  factory DoSale.fromJson(Map<String, dynamic> j) => DoSale(
        id: _asInt(j['id']),
        doId: _asInt(j['do_id']),
        doCode: j['do_code'] as String? ?? '',
        customerId: _asInt(j['customer_id']),
        customerName: j['customer_name'] as String? ?? '',
        customerVillage: j['customer_village'] as String?,
        customerMobile: j['customer_mobile'] as String?,
        saleDate: DateTime.parse(j['sale_date'] as String),
        variantId: _asInt(j['product_variant_id']),
        variantName: j['variant_name'] as String? ?? '',
        quantity: _asInt(j['quantity']),
        rate: _asDouble(j['rate']),
        gstRate: _asDouble(j['gst_rate']),
        emptyReturned: _asInt(j['empty_returned']),
        billId: j['bill_id'] == null ? null : _asInt(j['bill_id']),
        billNumber: j['bill_number'] as String?,
      );
}

class DoSaleVariantTotal {
  final String variantName;
  final int qty;
  DoSaleVariantTotal(this.variantName, this.qty);
}

class DoSaleSummary {
  final int totalQty;
  final int customerCount;
  final List<DoSaleVariantTotal> byVariant;
  DoSaleSummary({
    required this.totalQty,
    required this.customerCount,
    required this.byVariant,
  });

  factory DoSaleSummary.fromJson(Map<String, dynamic> j) => DoSaleSummary(
        totalQty: _asInt(j['total_qty']),
        customerCount: _asInt(j['customer_count']),
        byVariant: (j['by_variant'] as List? ?? [])
            .map((e) => DoSaleVariantTotal(
                  (e as Map)['variant_name'] as String? ?? '',
                  _asInt(e['qty']),
                ))
            .toList(),
      );
}

/// What the admin's New Bill screen opens with when billing a DO's sales:
/// the customer, the lines to bill, and the DO sale ids the saved bill will
/// settle.
class DoBillPrefill {
  final Customer customer;
  final DateTime billDate;
  final List<BillItemDraft> items;
  final List<int> doSaleIds;
  DoBillPrefill({
    required this.customer,
    required this.billDate,
    required this.items,
    required this.doSaleIds,
  });
}
