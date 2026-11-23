import 'package:bull_ui/src/chrome/bull_scaffold.dart';
import 'package:bull_ui/src/data_display/bull_details_table.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Destination content while the API has not returned an invoice yet.
class BullPaymentPreparationView extends StatelessWidget {
  final String title;
  final List<String> detailLabels;
  final String? errorMessage;
  final VoidCallback onBack;

  const BullPaymentPreparationView({
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
      child: BullScaffold(
        backgroundColor: context.bull.background,
        appBar: AppBar(title: Text(title)),
        body: message != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(BullSpacing.lg),
                  child: BullText(
                    message,
                    role: BullTextRole.body,
                    textAlign: TextAlign.center,
                    color: context.bull.error,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(BullSpacing.lg),
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
