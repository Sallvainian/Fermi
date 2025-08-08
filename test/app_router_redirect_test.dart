import 'package:flutter_test/flutter_test.dart';

// Use the firebase package name because the test environment registers
// the code under `teacher_dashboard_flutter_firebase`. Import the
// redirect helper and the unified AuthProvider from their new
// locations.
import 'package:teacher_dashboard_flutter_firebase/shared/routing/auth_redirect.dart';
import 'package:teacher_dashboard_flutter_firebase/features/auth/providers/auth_provider.dart';

void main() {
  group('computeAuthRedirect', () {
    test('Unauthenticated user accessing protected route is redirected to login', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.unauthenticated,
        emailVerified: false,
        matchedLocation: '/teacher/classes',
        role: null,
      );
      expect(result, '/auth/login');
    });

    test('Unauthenticated user accessing auth route is allowed', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.unauthenticated,
        emailVerified: false,
        matchedLocation: '/auth/login',
        role: null,
      );
      expect(result, isNull);
    });

    test('Authenticated user accessing auth route is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/auth/login',
        role: UserRole.teacher,
      );
      expect(result, '/dashboard');
    });

    test('User needing role selection redirected to role selection', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticating,
        emailVerified: false,
        matchedLocation: '/dashboard',
        role: null,
      );
      expect(result, '/auth/role-selection');
    });

    test('User needing role selection stays on role selection', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticating,
        emailVerified: false,
        matchedLocation: '/auth/role-selection',
        role: null,
      );
      expect(result, isNull);
    });

    test('User needing role selection accessing other auth route is redirected to role selection', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticating,
        emailVerified: false,
        matchedLocation: '/auth/signup',
        role: null,
      );
      expect(result, '/auth/role-selection');
    });

    test('Fully authenticated user accessing role selection is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/auth/role-selection',
        role: UserRole.teacher,
      );
      expect(result, '/dashboard');
    });

    test('Uninitialized status treated as unauthenticated and redirected to login', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.uninitialized,
        emailVerified: false,
        matchedLocation: '/teacher/grades',
        role: null,
      );
      expect(result, '/auth/login');
    });

    test('Error status treated as unauthenticated and redirected to login', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.error,
        emailVerified: false,
        matchedLocation: '/student/courses',
        role: null,
      );
      expect(result, '/auth/login');
    });

    test('Authenticated user with unverified email is redirected to verify email', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: false,
        matchedLocation: '/teacher/classes',
        role: UserRole.teacher,
      );
      expect(result, '/auth/verify-email');
    });

    test('Authenticated user with unverified email can access verify email route', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: false,
        matchedLocation: '/auth/verify-email',
        role: UserRole.teacher,
      );
      expect(result, isNull);
    });

    test('Authenticated user with verified email accessing verify email route is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/auth/verify-email',
        role: UserRole.teacher,
      );
      expect(result, '/dashboard');
    });

    test('Teacher user accessing student route is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/student/courses',
        role: UserRole.teacher,
      );
      expect(result, '/dashboard');
    });

    test('Student user accessing teacher route is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/teacher/classes',
        role: UserRole.student,
      );
      expect(result, '/dashboard');
    });
  });
}