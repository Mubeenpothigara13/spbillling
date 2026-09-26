// Repository for `/api/indents`.
import '../../core/api/api_client.dart';
import '../models/indent.dart';

class IndentPage {
  final List<Indent> items;
  final int page;
  final int total;
  final int lastPage;
  IndentPage({
    required this.items,
    required this.page,
    required this.total,
    required this.lastPage,
  });
}

class IndentRepo {
  final ApiClient _api;
  IndentRepo(this._api);

  /// Stock (cylinders sold) and rate per size for the caller's outlet.
  Future<List<IndentSize>> summary() async {
    final data = await _api.request('GET', '/indents/summary');
    return ((data as Map)['rows'] as List)
        .map((e) => IndentSize.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Submits an indent. `filled` / `empty` are keyed by size in kg.
  Future<Indent> submit({
    required Map<int, int> filled,
    required Map<int, int> empty,
    required double amountPaid,
  }) async {
    final data = await _api.request('POST', '/indents', data: {
      'items': [
        for (final kg in filled.keys)
          {'size_kg': kg, 'filled': filled[kg], 'empty': empty[kg] ?? 0},
      ],
      'amount_paid': amountPaid,
    });
    return Indent.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<IndentPage> list({int page = 1, int perPage = 25, int? doId}) async {
    final env = await _api.requestEnvelope('GET', '/indents', query: {
      'page': page,
      'per_page': perPage,
      if (doId != null) 'do_id': doId,
    });
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    final items = (env['data'] as List)
        .map((e) => Indent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return IndentPage(
      items: items,
      page: meta['page'] as int? ?? page,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<Indent> get(int id) async {
    final data = await _api.request('GET', '/indents/$id');
    return Indent.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Admin correction — `filled`/`empty` keyed by size in kg, same shape as
  /// [submit]. Re-prices off each item's own stored rate.
  Future<Indent> update(
    int id, {
    required Map<int, int> filled,
    required Map<int, int> empty,
    required double amountPaid,
  }) async {
    final data = await _api.request('PUT', '/indents/$id', data: {
      'items': [
        for (final kg in filled.keys)
          {'size_kg': kg, 'filled': filled[kg], 'empty': empty[kg] ?? 0},
      ],
      'amount_paid': amountPaid,
    });
    return Indent.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Indent> approve(int id) async {
    final data = await _api.request('POST', '/indents/$id/approve');
    return Indent.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Indent> reject(int id, {String? note}) async {
    final data = await _api.request('POST', '/indents/$id/reject', data: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return Indent.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
