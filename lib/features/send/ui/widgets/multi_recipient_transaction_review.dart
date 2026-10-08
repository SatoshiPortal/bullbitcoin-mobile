import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_info_row.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class MultiRecipientTransactionReview extends StatelessWidget {
  final String walletLabel;
  final List<SendRecipientDraft> recipients;
  final List<int> recipientAmountsSat;
  final String label;
  final String formattedAbsoluteFees;
  final String feePriorityTitle;
  final Widget Function(int amountSat) amountBuilder;
  final VoidCallback? onFeePriorityTap;
  final Widget? feeWarning;

  const MultiRecipientTransactionReview({
    super.key,
    required this.walletLabel,
    required this.recipients,
    required this.recipientAmountsSat,
    required this.label,
    required this.formattedAbsoluteFees,
    required this.feePriorityTitle,
    required this.amountBuilder,
    required this.onFeePriorityTap,
    required this.feeWarning,
  });

  Widget _divider(BuildContext context) =>
      Container(height: 1, color: context.appColors.secondaryFixedDim);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SendInfoRow(
            title: context.loc.coreScreensFromLabel,
            details: BBText(
              walletLabel,
              style: context.font.bodyLarge,
              color: context.appColors.secondary,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          for (var index = 0; index < recipients.length; index++) ...[
            SendInfoRow(
              title: context.loc.sendToRecipientNumber(index + 1),
              details: AddressViewer(
                recipients[index].address,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
              ),
            ),
            _divider(context),
            SendInfoRow(
              title: context.loc.coreScreensAmountLabel,
              details: Align(
                alignment: Alignment.centerRight,
                child: recipientAmountsSat.length > index
                    ? amountBuilder(recipientAmountsSat[index])
                    : BBText(
                        '…',
                        style: context.font.bodyLarge,
                        color: context.appColors.secondary,
                      ),
              ),
            ),
            _divider(context),
          ],
          if (label.isNotEmpty) ...[
            SendInfoRow(
              title: context.loc.receiveNote,
              details: BBText(
                label,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
                textAlign: TextAlign.end,
              ),
            ),
            _divider(context),
          ],
          SendInfoRow(
            title: context.loc.coreScreensNetworkFeesLabel,
            details: BBText(
              formattedAbsoluteFees,
              style: context.font.bodyLarge,
              color: context.appColors.secondary,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.coreScreensFeePriorityLabel,
            details: InkWell(
              onTap: onFeePriorityTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BBText(
                    feePriorityTitle,
                    style: context.font.bodyLarge,
                    color: context.appColors.primary,
                  ),
                  const Gap(4),
                  Icon(
                    Icons.arrow_forward_ios_sharp,
                    color: context.appColors.primary,
                    size: 12,
                  ),
                ],
              ),
            ),
          ),
          _divider(context),
          if (feeWarning != null) ...[const Gap(16), feeWarning!],
        ],
      ),
    );
  }
}
