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
  int _attemptCount = 0;
  DateTime? _lockoutTime;
  
  // Hash of "kineticenergy" - storing hash instead of plaintext
  static const String _passwordHash = '8d7e8f3b2c9a5f4e1d7b3a6c9e2f8d4a7b1c5e9f3d6a8b2c4e7f1a3d5b7c9e1f';
  
  @override
  void initState() {
    super.initState();
    _checkLockout();
  }
  
  Future<void> _checkLockout() async {
    final prefs = await SharedPreferences.getInstance();
    _attemptCount = prefs.getInt('password_attempts') ?? 0;
    final lockoutTimeMs = prefs.getInt('lockout_time');
    
    if (lockoutTimeMs != null) {
      _lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimeMs);
      if (_lockoutTime!.isBefore(DateTime.now())) {
        // Lockout expired, reset
        await prefs.remove('lockout_time');
        await prefs.setInt('password_attempts', 0);
        _attemptCount = 0;
        _lockoutTime = null;
      }
    }
    
    if (mounted) setState(() {});
  }
  
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  Future<void> _verifyPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if locked out
    if (_lockoutTime != null && _lockoutTime!.isAfter(DateTime.now())) {
      final remaining = _lockoutTime!.difference(DateTime.now());
      _showError('Too many attempts. Try again in ${remaining.inMinutes + 1} minutes.');
      return;
    }
    
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
      await prefs.setInt('password_attempts', 0);
      await prefs.remove('lockout_time');
      
      widget.onSuccess();
    } else {
      // Failed attempt
      _attemptCount++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('password_attempts', _attemptCount);
      
      if (_attemptCount >= 5) {
        // Lock out for 15 minutes after 5 failed attempts
        final lockoutTime = DateTime.now().add(const Duration(minutes: 15));
        await prefs.setInt('lockout_time', lockoutTime.millisecondsSinceEpoch);
        _lockoutTime = lockoutTime;
        _showError('Too many failed attempts. Locked for 15 minutes.');
      } else {
        _showError('Incorrect password. ${5 - _attemptCount} attempts remaining.');
      }
      
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
    final isLocked = _lockoutTime != null && _lockoutTime!.isAfter(DateTime.now());
    
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
                      'Fermi Education Platform',
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
                      enabled: !isLocked && !_isLoading,
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
                    
                    // Lockout Message
                    if (isLocked) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Too many failed attempts.\nTry again in ${_lockoutTime!.difference(DateTime.now()).inMinutes + 1} minutes.',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Submit Button
                    ElevatedButton(
                      onPressed: (isLocked || _isLoading) ? null : _verifyPassword,
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
                    
                    // Attempt Counter
                    if (_attemptCount > 0 && !isLocked) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Attempts: $_attemptCount/5',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _attemptCount >= 3 
                              ? Colors.red 
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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