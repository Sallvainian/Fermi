import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

enum VerificationState {
  enterEmail,
  verifyCode,
  success,
}

class EmailLinkingScreen extends StatefulWidget {
  final String userType; // 'teacher' or 'student'

  const EmailLinkingScreen({super.key, required this.userType});

  @override
  State<EmailLinkingScreen> createState() => _EmailLinkingScreenState();
}

class _EmailLinkingScreenState extends State<EmailLinkingScreen> {
  // State management
  VerificationState _verificationState = VerificationState.enterEmail;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = 
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = 
      List.generate(6, (_) => FocusNode());
  
  // Verification data
  String? _verificationId;
  String? _submittedEmail;
  DateTime? _codeExpiresAt;
  int _remainingAttempts = 3;
  
  // UI state
  bool _isLoading = false;
  bool _showSkipConfirmation = false;
  bool _canResend = false;
  Timer? _resendTimer;
  Timer? _expirationTimer;
  int _resendCountdown = 60;
  String? _errorMessage;
  
  // Email validation regex
  final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  bool get _isValidEmail {
    final text = _emailController.text.trim();
    return text.isNotEmpty && _emailRegex.hasMatch(text);
  }

  String get _verificationCode {
    return _codeControllers.map((c) => c.text).join();
  }

  bool get _isCodeComplete {
    return _verificationCode.length == 6 && 
           RegExp(r'^[0-9]+$').hasMatch(_verificationCode);
  }

  @override
  void initState() {
    super.initState();
    // Listen to text changes to enable/disable the button
    _emailController.addListener(() {
      setState(() {}); // Trigger rebuild when text changes
    });
    
    // Add listeners to code controllers for auto-advance
    for (int i = 0; i < _codeControllers.length; i++) {
      _codeControllers[i].addListener(() {
        if (_codeControllers[i].text.length == 1 && i < 5) {
          // Auto-advance to next field
          _codeFocusNodes[i + 1].requestFocus();
        }
        setState(() {}); // Update UI for button state
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _codeFocusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendEmailVerificationCode');
      
      final email = _emailController.text.trim();
      final result = await callable.call({'email': email});
      
      if (result.data['success'] == true) {
        setState(() {
          _verificationId = result.data['verificationId'];
          _submittedEmail = email;
          _codeExpiresAt = DateTime.parse(result.data['expiresAt']);
          _verificationState = VerificationState.verifyCode;
          _remainingAttempts = 3;
          
          // Start resend countdown
          _startResendCountdown();
          
          // Start expiration timer
          _startExpirationTimer();
        });
        
        // Focus first code field
        _codeFocusNodes[0].requestFocus();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code sent to $email'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      String errorMsg = 'Failed to send verification code';
      
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'already-exists':
            errorMsg = 'This email is already linked to another account';
            break;
          case 'resource-exhausted':
            errorMsg = 'Too many verification attempts. Please try again later.';
            break;
          case 'invalid-argument':
            errorMsg = 'Please enter a valid email address';
            break;
          default:
            errorMsg = e.message ?? errorMsg;
        }
      }
      
      setState(() {
        _errorMessage = errorMsg;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_isCodeComplete) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('verifyEmailCode');
      
      final result = await callable.call({
        'verificationId': _verificationId,
        'code': _verificationCode,
      });
      
      if (result.data['success'] == true) {
        // Refresh the auth provider's user model
        final authProvider = context.read<AuthProvider>();
        await authProvider.reloadUser();
        
        setState(() {
          _verificationState = VerificationState.success;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email successfully verified: ${result.data['email']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate to dashboard after short delay
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            context.go('/dashboard');
          }
        }
      }
    } catch (e) {
      String errorMsg = 'Verification failed';
      
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            // Parse remaining attempts from message if available
            if (e.message != null && e.message!.contains('attempt')) {
              errorMsg = e.message!;
              // Extract remaining attempts
              final match = RegExp(r'(\d+) attempt').firstMatch(e.message!);
              if (match != null) {
                _remainingAttempts = int.tryParse(match.group(1)!) ?? 0;
              }
            } else {
              errorMsg = 'Invalid verification code';
            }
            break;
          case 'deadline-exceeded':
            errorMsg = 'Verification code has expired. Please request a new one.';
            break;
          case 'resource-exhausted':
            errorMsg = 'Too many failed attempts. Please request a new code.';
            _remainingAttempts = 0;
            break;
          case 'failed-precondition':
            errorMsg = 'This code has already been used';
            break;
          default:
            errorMsg = e.message ?? errorMsg;
        }
      }
      
      setState(() {
        _errorMessage = errorMsg;
        
        // Clear code fields on error
        if (_remainingAttempts == 0 || 
            errorMsg.contains('expired') || 
            errorMsg.contains('already been used')) {
          for (var controller in _codeControllers) {
            controller.clear();
          }
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    
    // Reset to email entry state but keep the email
    setState(() {
      _verificationState = VerificationState.enterEmail;
      _verificationId = null;
      _remainingAttempts = 3;
      _canResend = false;
      _errorMessage = null;
      
      // Clear code fields
      for (var controller in _codeControllers) {
        controller.clear();
      }
    });
    
    // Cancel timers
    _resendTimer?.cancel();
    _expirationTimer?.cancel();
    
    // Send new code
    await _sendVerificationCode();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _canResend = false;
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _codeExpiresAt == null) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      if (now.isAfter(_codeExpiresAt!)) {
        setState(() {
          _errorMessage = 'Verification code has expired. Please request a new one.';
          _remainingAttempts = 0;
        });
        timer.cancel();
      }
    });
  }

  String _getExpirationText() {
    if (_codeExpiresAt == null) return '';
    
    final now = DateTime.now();
    final difference = _codeExpiresAt!.difference(now);
    
    if (difference.isNegative) {
      return 'Code expired';
    }
    
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    
    return 'Code expires in ${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  void _skipEmailLinking() {
    setState(() => _showSkipConfirmation = true);
  }

  void _confirmSkip() {
    // Navigate to dashboard without linking email
    context.go('/dashboard');
  }

  void _cancelSkip() {
    setState(() => _showSkipConfirmation = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.userModel?.username ?? 'User';
    final isTeacher = widget.userType == 'teacher';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _showSkipConfirmation
                  ? _buildSkipConfirmation(theme)
                  : _buildVerificationFlow(theme, username, isTeacher),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationFlow(ThemeData theme, String username, bool isTeacher) {
    switch (_verificationState) {
      case VerificationState.enterEmail:
        return _buildEmailForm(theme, username, isTeacher);
      case VerificationState.verifyCode:
        return _buildCodeVerification(theme, isTeacher);
      case VerificationState.success:
        return _buildSuccessScreen(theme, isTeacher);
    }
  }

  Widget _buildEmailForm(ThemeData theme, String username, bool isTeacher) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                (isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.email,
            size: 60,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Link Your Email',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'We\'ll send a verification code to confirm you own this email',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Username Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                (isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  (isTeacher
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: isTeacher
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Username',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isTeacher
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    username,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field
              AuthTextField(
                controller: _emailController,
                label: 'Email Address',
                prefixIcon: Icons.email,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                suffixIcon: _emailController.text.isNotEmpty
                    ? Icon(
                        _isValidEmail ? Icons.check_circle : Icons.error,
                        color: _isValidEmail ? Colors.green : Colors.red,
                      )
                    : null,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Only validate if user entered something
                    if (!_emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null; // Email is optional
                },
              ),
              
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),

              // Send Code Button
              ElevatedButton(
                onPressed: _isLoading || !_isValidEmail
                    ? null
                    : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isTeacher
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                  foregroundColor: isTeacher
                      ? theme.colorScheme.onSecondary
                      : theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Skip Button
              TextButton(
                onPressed: _isLoading ? null : _skipEmailLinking,
                child: Text(
                  'Skip for Now',
                  style: TextStyle(
                    color: isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),

              // Benefits Info
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Benefits of Linking Email',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Receive important notifications\n'
                      '• Reset your password if forgotten\n'
                      '• Recover your username\n'
                      '• Enhanced account security',
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeVerification(ThemeData theme, bool isTeacher) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _isLoading ? null : () {
              setState(() {
                _verificationState = VerificationState.enterEmail;
                _errorMessage = null;
                // Clear code fields
                for (var controller in _codeControllers) {
                  controller.clear();
                }
              });
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(height: 16),

        // Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                (isTeacher
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock,
            size: 60,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Enter Verification Code',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'We sent a 6-digit code to',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          _submittedEmail ?? '',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Code input fields
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              width: 50,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _codeControllers[index],
                focusNode: _codeFocusNodes[index],
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isTeacher
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                onChanged: (value) {
                  if (value.isEmpty && index > 0) {
                    // Move focus to previous field on backspace
                    _codeFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // Status indicators
        Column(
          children: [
            // Expiration timer
            Text(
              _getExpirationText(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (_remainingAttempts < 3) ...[
              const SizedBox(height: 8),
              Text(
                '$_remainingAttempts ${_remainingAttempts == 1 ? 'attempt' : 'attempts'} remaining',
                style: TextStyle(
                  color: _remainingAttempts == 1 
                      ? theme.colorScheme.error 
                      : Colors.orange,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),

        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Verify button
        ElevatedButton(
          onPressed: _isLoading || !_isCodeComplete || _remainingAttempts == 0
              ? null
              : _verifyCode,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
            foregroundColor: isTeacher
                ? theme.colorScheme.onSecondary
                : theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Text(
                  'Verify Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 12),

        // Resend button
        TextButton(
          onPressed: (_canResend && !_isLoading) ? _resendCode : null,
          child: Text(
            _canResend 
                ? 'Resend Code' 
                : 'Resend Code ($_resendCountdown s)',
            style: TextStyle(
              color: _canResend
                  ? (isTeacher
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen(ThemeData theme, bool isTeacher) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 60,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Email Verified!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Message
        Text(
          'Your email has been successfully verified',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _submittedEmail ?? '',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isTeacher
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Redirecting message
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Redirecting to dashboard...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSkipConfirmation(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Warning Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning, size: 60, color: Colors.orange),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          'Skip Email Linking?',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Warning Message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'Are you sure you don\'t want to link an email? Linking an email enables '
            'email notifications and enhanced account security as well as the ability '
            'to recover your password or username if you lose it. You can always link '
            'it later in the settings menu of your account.',
            style: TextStyle(fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // Buttons
        ElevatedButton(
          onPressed: _cancelSkip,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Go Back & Add Email',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: _confirmSkip,
          child: Text(
            'Continue Without Email',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 16),
          ),
        ),
      ],
    );
  }
}