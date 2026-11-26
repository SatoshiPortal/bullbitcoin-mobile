import '../../domain/send_amount_conversion.dart';

import 'package:bull_ui/app_theme.dart';
import 'package:send/src/send_localizations.dart';
import 'package:address_view/address_view.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/ui/widgets/send_info_row.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, BullTypographyX;
import 'package:material_ui/material_ui.dart';

class MultiRecipientTransactionReview extends StatelessWidget {
  final String walletLabel;
  final List<SendRecipientDraft> recipients;
  final List<int> recipientAmountsSat;
  final String label;
  final String formattedAbsoluteFees;
  final Widget Function(int amountSat) amountBuilder;
  final Widget? selectedCoinsDetails;
  final Map<int, SendAmountConversion> conversions;

  const MultiRecipientTransactionReview({
    super.key,
    required this.walletLabel,
    required this.recipients,
    required this.recipientAmountsSat,
    required this.label,
    required this.formattedAbsoluteFees,
    required this.amountBuilder,
    this.selectedCoinsDetails,
    this.conversions = const {},
  });

  Widget _divider(BuildContext context) =>
      Container(height: 1, color: context.appColors.border);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SendInfoRow(
            title: context.loc.coreScreensFromLabel,
            details: BullText(
              walletLabel,
              style: context.bullType.body,
              color: context.appColors.text,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
          for (var index = 0; index < recipients.length; index++) ...[
            SendInfoRow(
              title: context.loc.sendToRecipientNumber(index + 1),
              details: AddressViewer(
                recipients[index].address,
                style: context.bullType.body,
                color: context.appColors.text,
              ),
            ),
            _divider(context),
            SendInfoRow(
              title: context.loc.coreScreensAmountLabel,
              details: Align(
                alignment: Alignment.centerRight,
                child: recipientAmountsSat.length > index
                    ? amountBuilder(recipientAmountsSat[index])
                    : BullText(
                        '…',
                        style: context.bullType.body,
                        color: context.appColors.text,
                      ),
              ),
            ),
            if (conversions[recipients[index].id] case final conversion?)
              Text(
                context.loc.amountEnteredAtRate(
                  conversion.enteredText,
                  conversion.currencyCode,
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(conversion.quotedAt.toLocal()),
                    alwaysUse24HourFormat: true,
                  ),
                ),
                style: context.bullType.label.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.end,
              ),
            _divider(context),
          ],
          if (label.isNotEmpty) ...[
            SendInfoRow(
              title: context.loc.receiveNote,
              details: BullText(
                label,
                style: context.bullType.body,
                color: context.appColors.text,
                textAlign: TextAlign.end,
              ),
            ),
            _divider(context),
          ],
          if (selectedCoinsDetails case final details?) ...[
            SendInfoRow(title: context.loc.sendCoinControl, details: details),
            _divider(context),
          ],
          SendInfoRow(
            title: context.loc.coreScreensNetworkFeesLabel,
            details: BullText(
              formattedAbsoluteFees,
              style: context.bullType.body,
              color: context.appColors.text,
              textAlign: TextAlign.end,
            ),
          ),
          _divider(context),
        ],
      ),
    );
  }
}
