// Import the AuthProvider from the unified providers directory. This avoids
// duplicating AuthStatus and ensures tests reference the same provider.
import '../../features/auth/providers/auth_provider.dart';
import '../models/user_model.dart';

/// Compute the appropriate redirect based on authentication state.
///
/// This top‑level function encapsulates the routing rules for handling
/// unauthenticated users and role-based access control.
/// It can be unit tested in isolation without pulling in UI dependencies
/// or `go_router` types.
///
/// * [isAuthenticated] indicates whether the user is fully authenticated
///   (i.e. `AuthStatus.authenticated`).
/// * [status] is the full `AuthStatus` from the provider.
/// * [matchedLocation] is the current route path being requested.
/// * [role] is the user's role for role-based access control.
///
/// Returns a string path to redirect to, or `null` if no redirect is
/// necessary.
String? computeAuthRedirect({
  required bool isAuthenticated,
  required AuthStatus status,
  required String matchedLocation,
  UserRole? role,
}) {
  final bool isAuthRoute = matchedLocation.startsWith('/auth');
  final bool unauthenticated = !isAuthenticated;

  if (unauthenticated) {
    if (!isAuthRoute) {
      return '/auth/login';
    }
    return null;
  }

  // Role‑based route protection. Once the user is authenticated, restrict
  // access to routes based on their assigned role.
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
