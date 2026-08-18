import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bull_ui/bull_ui.dart';

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
      return BullText(
        message,
        style: context.bullText.bodyMedium,
        color: context.bull.error,
        textAlign: textAlign,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullText(
          title,
          style: context.bullText.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.bull.error,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 4),
        BullText(
          message,
          style: context.bullText.bodyMedium,
          color: context.bull.error,
          textAlign: textAlign,
        ),
      ],
    );
  }
}
