import 'package:flutter/material.dart';

/// Custom RadioListTile implementation to avoid false deprecation warnings
/// in Flutter 3.35.1 where RadioGroup doesn't exist yet.
class CustomRadioListTile<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final ListTileControlAffinity controlAffinity;
  final bool autofocus;
  final bool? enableFeedback;
  final Color? activeColor;
  final WidgetStateProperty<Color?>? fillColor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final double? splashRadius;
  final MaterialTapTargetSize? materialTapTargetSize;
  final VisualDensity? visualDensity;
  final FocusNode? focusNode;
  final bool toggleable;
  final Color? selectedTileColor;
  final ShapeBorder? shape;
  final Color? tileColor;
  final bool enabled;
  final ListTileTitleAlignment? titleAlignment;

  const CustomRadioListTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.dense,
    this.contentPadding,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.autofocus = false,
    this.enableFeedback,
    this.activeColor,
    this.fillColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.toggleable = false,
    this.selectedTileColor,
    this.shape,
    this.tileColor,
    this.enabled = true,
    this.titleAlignment,
  });

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use_from_same_package, deprecated_member_use
    final Widget control = Radio<T>(
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      // ignore: deprecated_member_use
      onChanged: enabled ? onChanged : null,
      activeColor: activeColor,
      fillColor: fillColor,
      hoverColor: hoverColor,
      overlayColor: overlayColor,
      splashRadius: splashRadius,
      materialTapTargetSize: materialTapTargetSize,
      autofocus: autofocus,
      focusNode: focusNode,
      toggleable: toggleable,
      visualDensity: visualDensity,
    );

    Widget? leading;
    Widget? trailing;
    
    switch (controlAffinity) {
      case ListTileControlAffinity.leading:
        leading = control;
        trailing = secondary;
        break;
      case ListTileControlAffinity.trailing:
      case ListTileControlAffinity.platform:
        leading = secondary;
        trailing = control;
        break;
    }

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: enabled && onChanged != null
          ? () {
              if (!toggleable || value != groupValue) {
                onChanged!(value);
              } else if (toggleable) {
                onChanged!(null);
              }
            }
          : null,
      dense: dense,
      contentPadding: contentPadding,
      enabled: enabled,
      selected: value == groupValue,
      selectedTileColor: selectedTileColor,
      shape: shape,
      tileColor: tileColor,
      enableFeedback: enableFeedback ?? true,
      titleAlignment: titleAlignment,
    );
  }
}