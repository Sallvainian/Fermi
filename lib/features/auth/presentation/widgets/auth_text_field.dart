import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLines;
  final bool showCapsLockIndicator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.showCapsLockIndicator = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _capsLockOn = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Only check caps lock for password fields
    if (widget.showCapsLockIndicator && widget.obscureText) {
      // Check caps lock state when focus changes
      _focusNode.addListener(_checkCapsLock);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_checkCapsLock);
    _focusNode.dispose();
    super.dispose();
  }

  void _checkCapsLock() {
    // ONLY use HardwareKeyboard API - no text pattern analysis
    // Text pattern analysis is unreliable for passwords
    if (_focusNode.hasFocus) {
      final capsLockOn = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
      if (capsLockOn != _capsLockOn) {
        setState(() {
          _capsLockOn = capsLockOn;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build the suffix widget - combine caps lock indicator with existing suffix
    Widget? finalSuffixIcon = widget.suffixIcon;
    
    if (widget.showCapsLockIndicator && widget.obscureText && _capsLockOn) {
      final capsLockIndicator = Tooltip(
        message: 'Caps Lock is ON',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.warningContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'CAPS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onWarningContainer,
            ),
          ),
        ),
      );

      if (finalSuffixIcon != null) {
        // Combine caps lock indicator with existing suffix
        finalSuffixIcon = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            capsLockIndicator,
            finalSuffixIcon,
          ],
        );
      } else {
        finalSuffixIcon = capsLockIndicator;
      }
    }

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: finalSuffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: widget.enabled
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
    );
  }
}

// Extension to add warning colors to ColorScheme
extension CustomColors on ColorScheme {
  Color get warningContainer => brightness == Brightness.light
      ? const Color(0xFFFFF3CD) // Light amber background
      : const Color(0xFF664D03); // Dark amber background
      
  Color get onWarningContainer => brightness == Brightness.light
      ? const Color(0xFF664D03) // Dark amber text
      : const Color(0xFFFFF3CD); // Light amber text
}
