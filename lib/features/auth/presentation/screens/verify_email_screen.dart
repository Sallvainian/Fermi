import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Import the AuthProvider from the common providers directory. The original
// relative import assumed the provider lived under `auth/providers`, not
// `auth/presentation/providers`. Updating the path here ensures the screen
// references the unified provider.
import '../../providers/auth_provider.dart';

/// Screen that prompts the user to verify their email address.
///
/// When a user registers with an email and password, Firebase requires
/// them to confirm their email address before full access is granted. This
/// screen provides a simple interface to resend the verification email and
/// check whether the verification has been completed. Once the email is
/// verified, navigating away is automatically handled by the router.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sent = false;
  bool _loading = false;
  String? _error;

  Future<void> _sendVerification() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendEmailVerification();
      setState(() {
        _sent = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().reloadUser();
      // After reloading, the router will handle the redirect if the
      // email has been verified (computeRedirect will kick in). We
      // explicitly call context.go here to ensure that when the
      // verification is complete and the user is still on this page,
      // they are sent to the dashboard.
      if (!mounted) return;

      if (context.read<AuthProvider>().firebaseUser?.emailVerified ?? false) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.firebaseUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Sign out to allow user to go back to login
            context.read<AuthProvider>().signOut();
            context.go('/auth/login');
          },
        ),
        title: const Text('Verify Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please verify your email address to continue.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'We sent a verification email to: \n$email',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_sent)
              const Text(
                'Verification email sent. Please check your inbox.',
                style: TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _sendVerification,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend Verification Email'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _refresh,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('I have verified'),
            ),
          ],
        ),
      ),
    );
  }
}
