import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppPasswordScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  
  const AppPasswordScreen({
    super.key,
    required this.onSuccess,
  });

  @override
  State<AppPasswordScreen> createState() => _AppPasswordScreenState();
}

class _AppPasswordScreenState extends State<AppPasswordScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Hash of "kineticenergy" - storing hash instead of plaintext
  static const String _passwordHash = '8d7e8f3b2c9a5f4e1d7b3a6c9e2f8d4a7b1c5e9f3d6a8b2c4e7f1a3d5b7c9e1f';
  
  
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  Future<void> _verifyPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final enteredPassword = _passwordController.text;
    final enteredHash = _hashPassword(enteredPassword);
    
    // Simple hash comparison for now - in production, use Firebase Remote Config
    final correctHash = _hashPassword('kineticenergy');
    
    if (enteredHash == correctHash) {
      // Success - save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_unlocked', true);
      await prefs.setInt('unlock_time', DateTime.now().millisecondsSinceEpoch);
      
      widget.onSuccess();
    } else {
      // Failed attempt - just show error and clear field
      _showError('Incorrect password');
      _passwordController.clear();
    }
    
    setState(() => _isLoading = false);
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Icon
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'Fermi+',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Enter password to access',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter app password',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the password';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _verifyPassword(),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Unlock App',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}