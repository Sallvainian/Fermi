import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_dashboard_flutter_firebase/shared/routing/auth_redirect.dart';
import 'package:teacher_dashboard_flutter_firebase/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('computeAuthRedirect', () {
    test('Unauthenticated user accessing protected route is redirected to login', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.unauthenticated,
        emailVerified: false,
        matchedLocation: '/teacher/classes',
      );
      expect(result, '/auth/login');
    });

    test('Unauthenticated user accessing auth route is allowed', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.unauthenticated,
        emailVerified: false,
        matchedLocation: '/auth/login',
      );
      expect(result, isNull);
    });

    test('Authenticated user accessing auth route is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/auth/login',
      );
      expect(result, '/dashboard');
    });

    test('User needing role selection redirected to role selection', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticating,
        emailVerified: false,
        matchedLocation: '/dashboard',
      );
      expect(result, '/auth/role-selection');
    });

    test('User needing role selection stays on role selection', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticating,
        emailVerified: false,
        matchedLocation: '/auth/role-selection',
      );
      expect(result, isNull);
    });

    test('User needing role selection accessing other auth route is redirected to role selection', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticating,
        emailVerified: false,
        matchedLocation: '/auth/signup',
      );
      expect(result, '/auth/role-selection');
    });

    test('Fully authenticated user accessing role selection is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/auth/role-selection',
      );
      expect(result, '/dashboard');
    });

    test('Uninitialized status treated as unauthenticated and redirected to login', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.uninitialized,
        emailVerified: false,
        matchedLocation: '/teacher/grades',
      );
      expect(result, '/auth/login');
    });

    test('Error status treated as unauthenticated and redirected to login', () {
      final result = computeAuthRedirect(
        isAuthenticated: false,
        status: AuthStatus.error,
        emailVerified: false,
        matchedLocation: '/student/courses',
      );
      expect(result, '/auth/login');
    });

    test('Authenticated user with unverified email is redirected to verify email', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: false,
        matchedLocation: '/teacher/classes',
      );
      expect(result, '/auth/verify-email');
    });

    test('Authenticated user with unverified email can access verify email route', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: false,
        matchedLocation: '/auth/verify-email',
      );
      expect(result, isNull);
    });

    test('Authenticated user with verified email accessing verify email route is redirected to dashboard', () {
      final result = computeAuthRedirect(
        isAuthenticated: true,
        status: AuthStatus.authenticated,
        emailVerified: true,
        matchedLocation: '/auth/verify-email',
      );
      expect(result, '/dashboard');
    });
  });
}