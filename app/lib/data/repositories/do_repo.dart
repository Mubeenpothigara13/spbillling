// Repository for Distributor Outlet (DO) CRUD at `/api/distributor-outlets`.
import '../../core/api/api_client.dart';
import '../models/distributor_outlet.dart';

/// Paginated slice returned by [DORepo.list].
class DOPage {
  final List<DistributorOutlet> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
  DOPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });
}

/// Distributor Outlet CRUD + typeahead search.
class DORepo {
  final ApiClient _api;
  DORepo(this._api);

  /// Paginated list with optional search and active filter.
  Future<DOPage> list({
    int page = 1,
    int perPage = 25,
    String? q,
    bool? active,
  }) async {
    final env = await _api.requestEnvelope('GET', '/distributor-outlets', query: {
      'page': page,
      'per_page': perPage,
      if (q != null && q.isNotEmpty) 'q': q,
      if (active != null) 'active': active,
    });
    final items = (env['data'] as List)
        .map((e) => DistributorOutlet.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    return DOPage(
      items: items,
      page: meta['page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Typeahead search used in the customer form's DO picker.
  Future<List<DistributorOutlet>> search(String q, {int limit = 20}) async {
    if (q.trim().isEmpty) return [];
    final data = await _api.request('GET', '/distributor-outlets/search',
        query: {'q': q, 'limit': limit});
    return (data as List)
        .map((e) => DistributorOutlet.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Fetches a single DO by id.
  Future<DistributorOutlet> get(int id) async {
    final data = await _api.request('GET', '/distributor-outlets/$id');
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Creates a new outlet. Backend enforces unique `code`.
  Future<DistributorOutlet> create(DistributorOutlet outlet) async {
    final data = await _api.request('POST', '/distributor-outlets',
        data: outlet.toCreateJson());
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Updates mutable fields (owner, location, code). Active flag toggles
  /// go through [setActive] instead.
  Future<DistributorOutlet> update(int id, DistributorOutlet outlet) async {
    final data = await _api.request('PUT', '/distributor-outlets/$id',
        data: outlet.toUpdateJson());
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Toggles active status. Backend blocks deactivation if active
  /// customers still reference the outlet.
  Future<DistributorOutlet> setActive(int id, bool active) async {
    final data = await _api.request('PATCH', '/distributor-outlets/$id/active',
        query: {'active': active});
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Soft-deletes the outlet. Fails if any active customer uses it.
  Future<void> delete(int id) async {
    await _api.request('DELETE', '/distributor-outlets/$id');
  }
}
