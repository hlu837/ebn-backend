import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Solid red pill button with a built-in loading spinner state (matches the
/// landing page and visitor dashboard CTA style).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primaryYellow,
        foregroundColor: foregroundColor ?? Colors.white,
        disabledBackgroundColor: (backgroundColor ?? AppColors.primaryYellow).withValues(alpha: 0.6),
      ),
      child: isLoading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? Colors.white,
                ),
              ),
            )
          : Text(label),
    );
  }
}

/// Outlined pill button, used for secondary actions.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.borderColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: borderColor ?? AppColors.ink, width: 1.6),
        foregroundColor: textColor ?? AppColors.ink,
      ),
      child: Text(label),
    );
  }
}

/// Small helper to show consistent error/success toasts across the app.
class AppToast {
  AppToast._();

  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.danger);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.success);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
          margin: const EdgeInsets.all(AppSpacing.md),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
  }
}
