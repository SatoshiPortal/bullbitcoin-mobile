import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BullText(
            currentFailure is RecipientsNetworkFailure
                ? '${context.loc.oopsSomethingWentWrong}\n'
                      '${currentFailure.toTranslated(context)}'
                : context.loc.oopsSomethingWentWrong,
            textAlign: TextAlign.center,
            style: context.font.bodyMedium,
            color: context.appColors.error,
          ),
          const Gap(8),
          BullButton.small(
            label: context.loc.retry,
            compact: true,
            onPressed: onRetry,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
      ),
    );
  }
}
