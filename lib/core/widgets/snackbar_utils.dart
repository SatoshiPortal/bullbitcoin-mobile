import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showCopiedSnackBar(BuildContext context) {
    _showSnackBar(
      context,
      const Text(
        'Copied to clipboard',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.white),
      ),
    );
  }

  static void showSnackBar(BuildContext context, String message) {
    _showSnackBar(
      context,
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
    );
  }

  static void showSnackBarWithContent(BuildContext context, Widget content) {
    _showSnackBar(context, content);
  }

  static void _showSnackBar(BuildContext context, Widget content) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        duration: const Duration(seconds: 2),
        backgroundColor: theme.colorScheme.onSurface.withAlpha(204),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
