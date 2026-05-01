// Repository for authentication endpoints (`/api/auth/*`).
//
// Kept thin — just maps JSON to LoginResponse / AppUser. The actual
// token persistence is handled by AuthStorage via the auth controller.
import '../../core/api/api_client.dart';
import '../models/user.dart';

/// Wraps `POST /auth/login` and `GET /auth/me`.
class AuthRepo {
  final ApiClient _api;
  AuthRepo(this._api);

  /// Exchanges username/password for a JWT. Throws [ApiError] on 401.
  Future<LoginResponse> login(String username, String password) async {
    final data = await _api.request('POST', '/auth/login', data: {
      'username': username,
      'password': password,
    });
    return LoginResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Returns the currently authenticated user profile. Used on app boot
  /// to verify a stored token is still valid.
  Future<AppUser> me() async {
    final data = await _api.request('GET', '/auth/me');
    return AppUser.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
