import 'package:flutter/material.dart';

enum CustomButtonType { filled, outlined }

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final CustomButtonType type;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.type = CustomButtonType.filled,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius = 100,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final defaultBg = type == CustomButtonType.filled
        ? colorScheme.primary
        : null;
    final defaultFg = type == CustomButtonType.filled
        ? colorScheme.onPrimary
        : colorScheme.primary;

    if (type == CustomButtonType.filled) {
      if (icon != null) {
        return FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: child,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor ?? defaultBg,
            foregroundColor: foregroundColor ?? defaultFg,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      } else {
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor ?? defaultBg,
            foregroundColor: foregroundColor ?? defaultFg,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: child,
        );
      }
    } else {
      // Outlined
      if (icon != null) {
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16, color: foregroundColor ?? defaultFg),
          label: child,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? defaultFg,
            side: BorderSide(
              color:
                  borderColor ??
                  (foregroundColor ?? defaultFg).withValues(alpha: 0.4),
              width: 1.5,
            ),
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      } else {
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? defaultFg,
            side: BorderSide(
              color:
                  borderColor ??
                  (foregroundColor ?? defaultFg).withValues(alpha: 0.4),
              width: 1.5,
            ),
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: child,
        );
      }
    }
  }
}
