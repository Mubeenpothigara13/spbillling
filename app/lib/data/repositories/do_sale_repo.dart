// Repository for `/api/do-sales`.
import '../../core/api/api_client.dart';
import '../models/do_sale.dart';

class DoSalePage {
  final List<DoSale> items;
  final int page;
  final int total;
  final int lastPage;
  DoSalePage({
    required this.items,
    required this.page,
    required this.total,
    required this.lastPage,
  });
}

class DoSaleRepo {
  final ApiClient _api;
  DoSaleRepo(this._api);

  String _d(DateTime v) => v.toIso8601String().split('T').first;

  /// Records the lines in one request. Each line is
  /// `{customer_id, product_variant_id, quantity, rate, empty_returned}`.
  Future<void> create({
    required DateTime saleDate,
    required List<Map<String, dynamic>> lines,
  }) async {
    await _api.request('POST', '/do-sales', data: {
      'sale_date': _d(saleDate),
      'lines': lines,
    });
  }

  /// `status` is `pending`, `billed` or `all`. A DO-scoped login is always
  /// pinned to its own outlet by the server.
  Future<DoSalePage> list({
    String status = 'all',
    DateTime? fromDate,
    DateTime? toDate,
    int? doId,
    int? customerId,
    int page = 1,
    int perPage = 25,
  }) async {
    final env = await _api.requestEnvelope('GET', '/do-sales', query: {
      'status': status,
      if (fromDate != null) 'from': _d(fromDate),
      if (toDate != null) 'to': _d(toDate),
      if (doId != null) 'do_id': doId,
      if (customerId != null) 'customer_id': customerId,
      'page': page,
      'per_page': perPage,
    });
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    final items = (env['data'] as List)
        .map((e) => DoSale.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return DoSalePage(
      items: items,
      page: meta['page'] as int? ?? page,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Bills one customer's pending sales for a day (S.P. Gas only). Returns
  /// the new bill number.
  Future<String> createBill({
    required int customerId,
    required DateTime saleDate,
  }) async {
    final data = await _api.request('POST', '/do-sales/bill', data: {
      'customer_id': customerId,
      'sale_date': _d(saleDate),
    });
    return (data as Map)['bill_number'] as String;
  }

  Future<DoSaleSummary> summary({DateTime? fromDate, DateTime? toDate}) async {
    final data = await _api.request('GET', '/do-sales/summary', query: {
      if (fromDate != null) 'from': _d(fromDate),
      if (toDate != null) 'to': _d(toDate),
    });
    return DoSaleSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
