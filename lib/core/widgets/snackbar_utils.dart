import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showCopiedSnackBar(BuildContext context) {
    _showSnackBar(
      context,
      Text(
        'Copied to clipboard',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: context.appColors.onPrimary),
      ),
    );
  }

  static void showSnackBar(BuildContext context, String message) {
    _showSnackBar(
      context,
      Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: context.appColors.onPrimary),
      ),
    );
  }

  static void showSnackBarWithContent(BuildContext context, Widget content) {
    _showSnackBar(context, content);
  }

  static void _showSnackBar(BuildContext context, Widget content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        duration: const Duration(seconds: 2),
        backgroundColor: context.appColors.onSurface.withAlpha(204),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
