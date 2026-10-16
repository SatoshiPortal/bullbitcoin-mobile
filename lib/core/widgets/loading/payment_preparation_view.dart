import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullDetailsTableItem;
import 'package:flutter/material.dart';

/// Destination content while the API has not returned an invoice yet.
class PaymentPreparationView extends StatelessWidget {
  final String title;
  final List<String> detailLabels;
  final String? errorMessage;
  final VoidCallback onBack;

  const PaymentPreparationView({
    super.key,
    required this.title,
    required this.detailLabels,
    this.errorMessage,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final message = errorMessage;
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) onBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: message != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    for (final label in detailLabels)
                      BullDetailsTableItem(label: label),
                  ],
                ),
              ),
      ),
    );
  }
}
