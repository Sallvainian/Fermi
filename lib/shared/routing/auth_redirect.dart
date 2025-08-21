// Import the AuthProvider from the unified providers directory. This avoids
// duplicating AuthStatus and ensures tests reference the same provider.
import '../../features/auth/providers/auth_provider.dart';
import '../models/user_model.dart';

/// Compute the appropriate redirect based on authentication state.
///
/// This top‑level function encapsulates the routing rules for handling
/// unauthenticated users, users who still need to select a role, and users
/// who must verify their email address. It can be unit tested in
/// isolation without pulling in UI dependencies or `go_router` types.
///
/// * [isAuthenticated] indicates whether the user is fully authenticated
///   (i.e. `AuthStatus.authenticated`).
/// * [status] is the full `AuthStatus` from the provider; `authenticating`
///   indicates that the user still needs to select a role.
/// * [emailVerified] reflects whether the currently signed‑in user's
///   email has been verified via Firebase.
/// * [matchedLocation] is the current route path being requested.
///
/// Returns a string path to redirect to, or `null` if no redirect is
/// necessary.
String? computeAuthRedirect({
  required bool isAuthenticated,
  required AuthStatus status,
  required bool emailVerified,
  required String matchedLocation,
  UserRole? role,
}) {
  final bool isAuthRoute = matchedLocation.startsWith('/auth');
  final bool unauthenticated = !isAuthenticated;
  final bool needsRoleSelection = status == AuthStatus.authenticating;
  final bool needsEmailVerification =
      isAuthenticated && !needsRoleSelection && !emailVerified;

  if (unauthenticated) {
    if (!isAuthRoute) {
      return '/auth/login';
    }
    return null;
  }

  if (needsRoleSelection) {
    if (matchedLocation != '/auth/role-selection') {
      return '/auth/role-selection';
    }
    return null;
  }

  if (needsEmailVerification) {
    if (matchedLocation != '/auth/verify-email') {
      return '/auth/verify-email';
    }
    return null;
  }

  // Role‑based route protection. Once the user is fully authenticated and
  // email verified, restrict access to routes based on their assigned role.
  // Teacher routes start with `/teacher`; student routes start with `/student`.
  if (matchedLocation.startsWith('/teacher') &&
      role != null &&
      role != UserRole.teacher) {
    return '/dashboard';
  }
  if (matchedLocation.startsWith('/student') &&
      role != null &&
      role != UserRole.student) {
    return '/dashboard';
  }

  if (isAuthRoute) {
    return '/dashboard';
  }

  return null;
}
