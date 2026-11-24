import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/recipients/presentation/payout_rail_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show BullDetailsTableItem;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// The deposit a payin from [source] goes to: showing it is the user's way
/// to notice if it ever changed under them.
Widget? payinDepositRow(
  BuildContext context, {
  required String label,
  required Order order,
  required PayinSource source,
  required ExchangePayinUi ui,
}) => switch (source.rail.rail.depositOf(order)) {
  DepositGiven(:final target) => BullDetailsTableItem(
    label: label,
    displayWidget: ui.addressViewer(context, switch (target) {
      OnchainDeposit(:final address) ||
      LiquidDeposit(:final address) => address,
      LightningInvoiceDeposit(:final invoice) => invoice,
    }, textAlign: TextAlign.end),
  ),
  DepositNotGiven() || DepositOnOtherRail() => null,
};

/// The payout rows of a recipient: its payout method, name and first
/// account detail (copyable).
List<Widget> recipientReviewRows(
  BuildContext context, {
  required ReadyRecipient recipient,
  required String methodLabel,
  required String nameLabel,
}) {
  final details = recipient.chosen.recipient.onRail;
  final account = details.accountRows.firstOrNull;
  return [
    BullDetailsTableItem(
      label: methodLabel,
      displayValue: recipient.rail.label(context),
    ),
    BullDetailsTableItem(label: nameLabel, displayValue: details.displayName),
    if (account != null)
      BullDetailsTableItem(
        label: account.field.label(context),
        displayValue: account.value,
        copyValue: account.value,
        copiedMessage: context.loc.copiedToClipboard,
      ),
  ];
}

/// The payin amount in sats of [order].
int payinAmountSat(Order order) => (order.payinAmount * 100000000).round();

/// The order's price in its payout currency per BTC, for the fee sheet's
/// fiat values; null when the order has no payin amount.
double? payinExchangeRate(Order order) =>
    order.payinAmount == 0 ? null : order.payoutAmount / order.payinAmount;

/// Whether the review offers the payjoin switch: an on-chain payin from an
/// app wallet to an order that published a payjoin URI.
bool payjoinOffered(Order order, PayinSource source) =>
    order.payjoinBip21 != null &&
    switch (source) {
      PayinFromAppWallet(rail: BtcNetwork.bitcoin) => true,
      PayinFromAppWallet() || PayinFromExternal() => false,
    };
