import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap;

/// Shown once a payin is on the network but the exchange reports the order's
/// payment deadline as expired: says so, keeps the transaction ID at hand for
/// support, and lets the user leave instead of waiting on a spinner.
class PayinPastDeadlineNotice extends StatelessWidget {
  const PayinPastDeadlineNotice({
    super.key,
    required this.transactionId,
    required this.onLeave,
  });

  final String transactionId;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InfoCard(
          description: context.loc.exchangePaymentSentPastDeadline,
          tagColor: context.appColors.tertiary,
          bgColor: context.appColors.tertiaryContainer,
        ),
        const Gap(12),
        CopyInput(text: transactionId, maxLines: 1, overflow: .ellipsis),
        const Gap(16),
        BullButton.big(
          label: context.loc.exchangePaymentSentLeave,
          onPressed: onLeave,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}
