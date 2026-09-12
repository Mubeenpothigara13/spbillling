// Repository for user-account CRUD at `/api/users` — global-admin only
// (the backend rejects these calls from a DO-scoped admin login).
import '../../core/api/api_client.dart';
import '../models/managed_user.dart';

/// Paginated slice returned by [UserRepo.list].
class UserPage {
  final List<ManagedUser> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
  UserPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });
}

class UserRepo {
  final ApiClient _api;
  UserRepo(this._api);

  Future<UserPage> list({int page = 1, int perPage = 100}) async {
    final env = await _api.requestEnvelope('GET', '/users', query: {
      'page': page,
      'per_page': perPage,
    });
    final items = (env['data'] as List)
        .map((e) => ManagedUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    return UserPage(
      items: items,
      page: meta['page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Creates a login. Leave [doId] null for a global S.P. Gas login;
  /// set it to lock this login to one Distributor Outlet.
  Future<ManagedUser> create({
    required String username,
    required String password,
    required String fullName,
    String? email,
    required String role,
    int? doId,
  }) async {
    final data = await _api.request('POST', '/users', data: {
      'username': username,
      'password': password,
      'full_name': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
      'role': role,
      if (doId != null) 'do_id': doId,
    });
    return ManagedUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Updates a login. Pass `clearDoId: true` to unlock a login back to a
  /// global S.P. Gas account; pass [doId] to (re)lock it to one outlet.
  Future<ManagedUser> update(
    int id, {
    String? fullName,
    String? email,
    String? role,
    bool? isActive,
    String? password,
    int? doId,
    bool clearDoId = false,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (email != null) body['email'] = email;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (clearDoId) {
      body['do_id'] = null;
    } else if (doId != null) {
      body['do_id'] = doId;
    }
    final data = await _api.request('PUT', '/users/$id', data: body);
    return ManagedUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Deactivates (soft-disables) a login — it can no longer sign in.
  Future<void> deactivate(int id) async {
    await _api.request('DELETE', '/users/$id');
  }
}
