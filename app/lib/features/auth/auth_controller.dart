// Central auth state for the app.
//
// The controller is created once on startup and drives:
//   * the splash → login → shell routing flow (via authControllerProvider
//     which the router listens to);
//   * the user chip in the top bar;
//   * the role gate on admin-only UI (e.g. "Print filtered" button).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

/// Immutable snapshot of the auth UI state.
class AuthState {
  final bool loading;
  final bool authenticated;
  final String? role;
  final String? fullName;
  final String? error;

  const AuthState({
    this.loading = false,
    this.authenticated = false,
    this.role,
    this.fullName,
    this.error,
  });

  AuthState copyWith({
    bool? loading,
    bool? authenticated,
    String? role,
    String? fullName,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        loading: loading ?? this.loading,
        authenticated: authenticated ?? this.authenticated,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives login/logout and restores a persisted session on app start.
class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthController(this._ref) : super(const AuthState()) {
    _bootstrap();
  }

  /// On startup, if a token exists in [AuthStorage] flip straight to
  /// `authenticated=true`. We don't hit `/me` here to keep the splash
  /// fast — any invalid token will fail the next real API call.
  Future<void> _bootstrap() async {
    final storage = _ref.read(authStorageProvider);
    final token = await storage.readToken();
    if (token != null && token.isNotEmpty) {
      final role = await storage.readRole();
      final name = await storage.readFullName();
      state = state.copyWith(authenticated: true, role: role, fullName: name);
    }
  }

  /// Attempts login; on success persists the session and returns `true`.
  /// On failure stores a human-readable error in [AuthState.error] and
  /// returns `false` so the login screen can show a snackbar.
  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = _ref.read(authRepoProvider);
      final resp = await repo.login(username, password);
      await _ref.read(authStorageProvider).saveSession(
            token: resp.accessToken,
            role: resp.role,
            userId: resp.userId,
            fullName: resp.fullName,
          );
      state = AuthState(
        loading: false,
        authenticated: true,
        role: resp.role,
        fullName: resp.fullName,
      );
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString().replaceFirst('ApiError(', '').replaceFirst('): ', ' — ').replaceAll(')', ''));
      return false;
    }
  }

  /// Clears persisted session and resets state. The router redirect
  /// listener will then bounce the user back to `/login`.
  Future<void> logout() async {
    await _ref.read(authStorageProvider).clear();
    state = const AuthState();
  }
}

/// Global Riverpod handle to the [AuthController].
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(ref));
