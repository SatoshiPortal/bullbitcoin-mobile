import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:flutter/material.dart';

class FundExchangeErrorText extends StatelessWidget {
  const FundExchangeErrorText({
    super.key,
    required this.error,
    this.textAlign = TextAlign.center,
  });

  final FundExchangePresentationError error;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final title = error.displayTitle(context.loc);
    final message = error.displayMessage(context.loc);

    if (title == null) {
      return BBText(
        message,
        style: context.font.bodyMedium,
        color: Theme.of(context).colorScheme.error,
        textAlign: textAlign,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          title,
          style: context.font.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        BBText(
          message,
          style: context.font.bodyMedium,
          color: Theme.of(context).colorScheme.error,
          textAlign: textAlign,
        ),
      ],
    );
  }
}
