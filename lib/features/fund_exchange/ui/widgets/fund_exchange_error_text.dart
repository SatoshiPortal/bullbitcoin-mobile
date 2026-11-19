import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_failure_l10n.dart';
import 'package:material_ui/material_ui.dart';

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
        style: context.bullType.body,
        color: Theme.of(context).colorScheme.error,
        textAlign: textAlign,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(
          title,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        BullText(
          message,
          style: context.bullType.body,
          color: Theme.of(context).colorScheme.error,
          textAlign: textAlign,
        ),
      ],
    );
  }
}
