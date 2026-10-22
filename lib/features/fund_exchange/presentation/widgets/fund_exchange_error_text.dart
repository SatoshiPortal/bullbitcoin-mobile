import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullText;

class FundExchangeErrorText extends StatelessWidget {
  const FundExchangeErrorText({
    super.key,
    required this.failure,
    this.textAlign = TextAlign.center,
  });

  final FundExchangeFailure failure;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final title = failure.toTranslatedTitle(context);
    final message = failure.toTranslated(context);

    if (title == null) {
      return BullText(
        message,
        style: context.font.bodyMedium,
        color: Theme.of(context).colorScheme.error,
        textAlign: textAlign,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(
          title,
          style: context.font.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        BullText(
          message,
          style: context.font.bodyMedium,
          color: Theme.of(context).colorScheme.error,
          textAlign: textAlign,
        ),
      ],
    );
  }
}
