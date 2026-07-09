import 'package:flutter/material.dart';

class TextLabelField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isRequired;
  final bool enabled;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const TextLabelField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isRequired = false,
    this.enabled = true,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      maxLines: maxLines,
      obscureText: obscureText,
      style: TextStyle(
        color: enabled
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        fontSize: maxLines > 1 ? 12 : 14,
        fontFamily: maxLines > 1 ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        errorStyle: TextStyle(color: colorScheme.error),
      ),
      validator:
          validator ??
          (isRequired
              ? (v) => (v == null || v.trim().isEmpty)
                    ? '$label is required'
                    : null
              : null),
    );
  }
}
