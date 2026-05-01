// Persistent storage for the current user's auth session.
//
// Backed by SharedPreferences. Stores the JWT access token plus a few
// convenience fields (role, user id, full name) so the app can restore the
// session and render the user chip in the top bar without hitting `/me`
// on every launch.
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny key/value wrapper around [SharedPreferences] for auth data.
///
/// All methods are async because [SharedPreferences.getInstance] is async.
/// On logout, call [clear] to wipe every key.
class AuthStorage {
  // Storage keys — kept private so callers can't read/write by raw string.
  static const _kToken = 'access_token';
  static const _kRole = 'role';
  static const _kUserId = 'user_id';
  static const _kFullName = 'full_name';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  /// Persists a full login session after a successful `/auth/login`.
  Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
    required String fullName,
  }) async {
    final p = await _p;
    await p.setString(_kToken, token);
    await p.setString(_kRole, role);
    await p.setInt(_kUserId, userId);
    await p.setString(_kFullName, fullName);
  }

  /// Returns the stored JWT bearer token, or `null` if not logged in.
  Future<String?> readToken() async => (await _p).getString(_kToken);

  /// Returns the stored role (`admin` | `billing_staff` | `viewer`).
  Future<String?> readRole() async => (await _p).getString(_kRole);

  /// Returns the stored human-readable full name (used in the UI chip).
  Future<String?> readFullName() async => (await _p).getString(_kFullName);

  /// Removes every session key — call on logout or 401 eviction.
  Future<void> clear() async {
    final p = await _p;
    await p.remove(_kToken);
    await p.remove(_kRole);
    await p.remove(_kUserId);
    await p.remove(_kFullName);
  }
}
