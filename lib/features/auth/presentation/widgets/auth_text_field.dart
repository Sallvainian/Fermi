import 'package:flutter/material.dart';
import '../../../../shared/services/caps_lock_service.dart';

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
  final _capsLockService = CapsLockService.instance;

  @override
  void initState() {
    super.initState();
    // Only check caps lock if indicator is requested
    if (widget.showCapsLockIndicator) {
      // Check caps lock state when focus changes
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _capsLockService.cancelPendingChecks();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.showCapsLockIndicator && widget.obscureText) {
      // Use the service to check caps lock with debouncing
      _capsLockService.checkCapsLockState(
        onStateChanged: (capsLockOn) {
          if (mounted && capsLockOn != _capsLockOn) {
            setState(() {
              _capsLockOn = capsLockOn;
            });
          }
        },
      );
    } else if (_capsLockOn && mounted) {
      // Clear caps lock state when unfocused
      setState(() {
        _capsLockOn = false;
      });
    }
  }

  /// Build the suffix icon, combining caps lock indicator with existing suffix
  Widget? _buildSuffixIcon(ThemeData theme) {
    final existingSuffix = widget.suffixIcon;
    
    // Return early if no caps lock indicator needed
    if (!widget.showCapsLockIndicator || !widget.obscureText || !_capsLockOn) {
      return existingSuffix;
    }
    
    // Build caps lock indicator
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
    
    // Combine with existing suffix if present
    if (existingSuffix != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [capsLockIndicator, existingSuffix],
      );
    }
    
    return capsLockIndicator;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        suffixIcon: _buildSuffixIcon(theme),
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
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
