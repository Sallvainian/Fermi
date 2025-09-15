import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../../../../shared/theme/app_spacing.dart';
import '../../../../../shared/widgets/common/adaptive_layout.dart';

/// Screen for students to enroll in classes using enrollment codes.
///
/// This screen provides a simple interface where students can enter
/// a 6-character enrollment code to join a class. It includes:
/// - Input field with proper formatting and validation
/// - Real-time feedback on enrollment status
/// - Error handling for invalid or expired codes
/// - Success confirmation with navigation options
class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isEnrolling = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Join a Class',
      showBackButton: true,
      onBackPressed: () => context.go('/dashboard'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Icon(
                    Icons.class_,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Enter Enrollment Code',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Ask your teacher for the 6-character class enrollment code',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Code input field
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'XXXXXX',
                      hintStyle: theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: 8,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      errorText: _errorMessage,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xl,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an enrollment code';
                      }
                      if (value.trim().length != 6) {
                        return 'Code must be exactly 6 characters';
                      }
                      // Check if it contains only valid characters
                      final validCode = RegExp(r'^[A-Z0-9]+$');
                      if (!validCode.hasMatch(value.trim().toUpperCase())) {
                        return 'Code can only contain letters and numbers';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Clear error when user starts typing
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                      // Auto-capitalize and limit to 6 characters
                      if (value.length > 6) {
                        _codeController.text = value.substring(0, 6);
                        _codeController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _codeController.text.length),
                        );
                      }
                    },
                    maxLength: 6,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) {
                          return Text(
                            '$currentLength / $maxLength',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: currentLength == maxLength
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Enroll button
                  FilledButton(
                    onPressed: _isEnrolling ? null : _handleEnrollment,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                    ),
                    child: _isEnrolling
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Join Class',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 51),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Enrollment codes are case-insensitive and expire after the semester ends',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleEnrollment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isEnrolling = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final classProvider = context.read<ClassProvider>();
      final studentId = authProvider.userModel?.uid;

      if (studentId == null) {
        throw Exception('No student ID found');
      }

      final success = await classProvider.enrollWithCode(
        studentId,
        _codeController.text.trim().toUpperCase(),
      );

      if (!mounted) return;

      if (success) {
        // Navigate first, then show a snackbar instead of dialog to avoid disposal issues
        if (mounted) {
          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully enrolled in class!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate to dashboard
          context.go('/dashboard');
        }
      } else {
        setState(() {
          // Parse the error message to provide better user feedback
          final error = classProvider.error ?? 'Failed to enroll in class';
          if (error.contains('Invalid enrollment code')) {
            _errorMessage = 'Invalid code. Please check with your teacher.';
          } else if (error.contains('already enrolled')) {
            _errorMessage = 'You are already enrolled in this class.';
          } else if (error.contains('permission-denied')) {
            _errorMessage = 'Access denied. Please make sure you are logged in as a student.';
          } else if (error.contains('blocked') || error.contains('ERR_BLOCKED')) {
            _errorMessage = 'Connection blocked. Please try again in a moment.';
          } else {
            _errorMessage = 'Unable to join class. Please try again or contact support.';
          }
        });
      }
    } catch (e) {
      setState(() {
        final errorStr = e.toString();
        if (errorStr.contains('not found') || errorStr.contains('Invalid')) {
          _errorMessage = 'Invalid enrollment code. Please check and try again.';
        } else if (errorStr.contains('already enrolled')) {
          _errorMessage = 'You are already enrolled in this class.';
        } else if (errorStr.contains('capacity')) {
          _errorMessage = 'This class is full and cannot accept new enrollments.';
        } else if (errorStr.contains('permission-denied')) {
          _errorMessage = 'Access denied. Please make sure you are logged in as a student.';
        } else if (errorStr.contains('No student ID')) {
          _errorMessage = 'Please log in to enroll in a class.';
        } else {
          _errorMessage = 'An error occurred. Please try again later.';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEnrolling = false;
        });
      }
    }
  }
}
