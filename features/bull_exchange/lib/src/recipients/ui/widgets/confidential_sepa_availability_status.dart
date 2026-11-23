import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';

class ConfidentialSepaAvailabilityStatus extends StatelessWidget {
  final RecipientsFailure? failure;
  final VoidCallback onRetry;

  const ConfidentialSepaAvailabilityStatus({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final currentFailure = failure;
    if (currentFailure == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BullErrorState(
        message: currentFailure is RecipientsNetworkFailure
            ? '${context.loc.oopsSomethingWentWrong}\n'
                  '${currentFailure.toTranslated(context)}'
            : context.loc.oopsSomethingWentWrong,
        onRetry: onRetry,
        retryLabel: context.loc.retry,
      ),
    );
  }
}
