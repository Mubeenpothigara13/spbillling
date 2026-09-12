// Data model for a user row managed from the Users screen (global-admin
// only). Distinct from `AppUser`/`LoginResponse` in user.dart, which model
// the *currently signed-in* session instead.
class ManagedUser {
  final int id;
  final String username;
  final String fullName;
  final String? email;
  final String role; // admin | billing_staff | viewer
  final bool isActive;
  // Set when this login is locked to one Distributor Outlet (null = S.P.
  // Gas — sees every DO).
  final int? doId;
  final DateTime? lastLogin;

  ManagedUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    required this.role,
    required this.isActive,
    this.doId,
    this.lastLogin,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> j) => ManagedUser(
        id: j['id'] as int,
        username: j['username'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String?,
        role: j['role'] as String,
        isActive: j['is_active'] as bool? ?? true,
        doId: j['do_id'] as int?,
        lastLogin: j['last_login'] != null
            ? DateTime.tryParse(j['last_login'] as String)
            : null,
      );
}
