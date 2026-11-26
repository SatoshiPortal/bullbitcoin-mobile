import 'package:silent/localizations.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:send/src/send_localizations.dart';
import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:address_view/payment_destination.dart'
    show FullScreenScannerPage;
import 'package:send/src/payment/presentation/bloc/send_state.dart';

import '../../domain/send_source.dart';
import '../../presentation/send_wallet_view.dart';

import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDropdown,
        BullPickerItem,
        BullInputText,
        BullPaymentDestinationInput,
        BullSpacing,
        BullTypographyX,
        Gap;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;

class RecipientAddressFields extends StatelessWidget {
  final List<SendRecipientDraft> recipients;
  final Widget primaryField;
  final bool multipleRecipients;
  final Map<int, SendSource> internalRecipientWallets;
  final ValueChanged<int> onRemoveRecipient;
  final Future<void> Function(int id, String value) onAddressChanged;

  const RecipientAddressFields({
    super.key,
    required this.recipients,
    required this.primaryField,
    required this.onRemoveRecipient,
    required this.onAddressChanged,
    this.multipleRecipients = false,
    this.internalRecipientWallets = const {},
  });

  @override
  Widget build(BuildContext context) {
    final collapsePrimary =
        multipleRecipients && recipients.isNotEmpty && recipients.first.isValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (collapsePrimary) ...[
          Text(context.loc.sendRecipients, style: context.bullType.body),
          const Gap(8),
          _RecipientRow(recipient: recipients.first, number: 1),
        ] else
          primaryField,
        for (var index = 1; index < recipients.length; index++) ...[
          const Gap(16),
          if (recipients[index].isValid)
            _RecipientRow(
              recipient: recipients[index],
              number: index + 1,
              wallet: internalRecipientWallets[recipients[index].id],
              onRemove: () => onRemoveRecipient(recipients[index].id),
            )
          else
            BullPaymentDestinationInput(
              key: ValueKey('send-recipient-address-${recipients[index].id}'),
              label: context.loc.sendRecipientAddressNumber(index + 1),
              value: recipients[index].address,
              hint: context.loc.sendPasteAddressOrInvoice,
              onChanged: (value) =>
                  onAddressChanged(recipients[index].id, value),
              pasteLabel: MaterialLocalizations.of(context).pasteButtonLabel,
              scanLabel: context.silentLoc.silentScan,
              clearLabel: context.silentLoc.silentClearButton,
              removeLabel: context.loc.sendRemoveRecipient,
              onRemove: () => onRemoveRecipient(recipients[index].id),
              onClear: () => onAddressChanged(recipients[index].id, ''),
              error: recipients[index].address.isNotEmpty
                  ? context.loc.sendErrorInvalidAddressOrInvoice
                  : null,
              onPaste: () async {
                final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
                if (clipboard == null || !context.mounted) return;
                await onAddressChanged(
                  recipients[index].id,
                  clipboard.text ?? '',
                );
              },
              onScan: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => FullScreenScannerPage(
                    onScannedPaymentRequest: (raw) =>
                        onAddressChanged(recipients[index].id, raw),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.number,
    this.wallet,
    this.onRemove,
  });

  final SendRecipientDraft recipient;
  final int number;
  final SendSource? wallet;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
      color: context.appColors.surface,
      border: Border(bottom: BorderSide(color: context.appColors.border)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: context.appColors.surfaceContainerHighest,
          child: Text(
            '$number',
            style: context.bullType.caption.copyWith(
              color: context.appColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (wallet case final ownWallet?)
                Text(
                  ownWallet.displayLabel(context),
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                AddressViewer(recipient.address, style: context.bullType.body),
              if (wallet != null)
                Row(
                  children: [
                    Text(
                      '${context.loc.sendMyWallet} · ',
                      style: context.bullType.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.appColors.textMuted,
                      ),
                    ),
                    Expanded(
                      child: AddressViewer(
                        recipient.address,
                        style: context.bullType.label.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  context.loc.exchangeDcaAddressLabelBitcoin,
                  style: context.bullType.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.appColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (onRemove != null)
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: context.loc.sendRemoveRecipient,
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 20, color: context.appColors.text),
            ),
          ),
      ],
    ),
  );
}

class AddRecipientButton extends StatelessWidget {
  final bool canAdd;
  final Future<void> Function() onAdd;
  final VoidCallback? onMyWallet;

  const AddRecipientButton({
    super.key,
    required this.canAdd,
    required this.onAdd,
    this.onMyWallet,
  });

  @override
  Widget build(BuildContext context) {
    if (!canAdd) return const SizedBox.shrink();
    final style = context.bullType.body.copyWith(fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.loc.sendAdd, style: context.bullType.body),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: BullButton.secondary(
                  label: context.loc.sendRecipient,
                  onPressed: onAdd,
                  iconData: Icons.person,
                  iconFirst: true,
                  height: 48,
                  textStyle: style,
                ),
              ),
              const Gap(8),
              Expanded(
                child: BullButton.secondary(
                  label: context.loc.sendMyWallet,
                  onPressed: onMyWallet,
                  iconData: Icons.account_balance_wallet,
                  iconFirst: true,
                  height: 48,
                  textStyle: style,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecipientAmounts extends StatelessWidget {
  final List<SendRecipientDraft> recipients;
  final List<int> preparedAmounts;
  final bool isSweep;
  final String inputCurrency;
  final Map<int, FocusNode> focusNodes;
  final Map<int, SendSource> internalRecipientWallets;
  final Set<int> qrAmountRecipientIds;
  final int? feeSat;
  final int fixedTotalSat;
  final Widget? amountHeader;
  final Widget Function(SendRecipientDraft recipient, FocusNode? focusNode)?
  amountFieldBuilder;
  final String? error;
  final ValueChanged<int> onRemoveRecipient;
  final Future<void> Function(int id, String value) onAmountChanged;
  final void Function(int id, bool receivesRemainder) onRemainderChanged;
  final Widget Function(int amountSat, {bool emphasized}) amountBuilder;

  const RecipientAmounts({
    super.key,
    required this.recipients,
    required this.preparedAmounts,
    required this.isSweep,
    required this.inputCurrency,
    required this.focusNodes,
    required this.error,
    required this.onRemoveRecipient,
    required this.onAmountChanged,
    required this.onRemainderChanged,
    required this.amountBuilder,
    this.internalRecipientWallets = const {},
    this.qrAmountRecipientIds = const {},
    this.feeSat,
    this.fixedTotalSat = 0,
    this.amountHeader,
    this.amountFieldBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final remainderId = recipients
        .where((recipient) => recipient.receivesRemainder)
        .firstOrNull
        ?.id;
    final hasRemainder = remainderId != null;
    final totalRecipients = hasRemainder
        ? preparedAmounts.length == recipients.length
              ? preparedAmounts.fold<int>(0, (total, amount) => total + amount)
              : null
        : fixedTotalSat;
    final fee = feeSat;
    final totalDebited = totalRecipients != null && fee != null
        ? totalRecipients + fee
        : null;
    final muted = context.bullType.label.copyWith(
      color: context.appColors.textMuted,
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.loc.sendRecipients,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?amountHeader,
          ],
        ),
        const Gap(BullSpacing.xs),
        Divider(height: 1, color: context.appColors.border),
        for (var index = 0; index < recipients.length; index++)
          _RecipientAmountRow(
            number: index + 1,
            recipient: recipients[index],
            wallet: internalRecipientWallets[recipients[index].id],
            note: recipients[index].receivesRemainder
                ? context.loc.sendRestCalculated
                : qrAmountRecipientIds.contains(recipients[index].id)
                ? context.loc.sendAmountFromQrEditable
                : null,
            amount: amountFieldBuilder != null
                ? Semantics(
                    label: context.loc.sendRecipientNumber(index + 1),
                    child: amountFieldBuilder?.call(
                      recipients[index],
                      focusNodes[recipients[index].id],
                    ),
                  )
                : BullInputText(
                    key: ValueKey(
                      'send-recipient-amount-${recipients[index].id}',
                    ),
                    onChanged: (value) =>
                        onAmountChanged(recipients[index].id, value),
                    // The rest is computed after fees, so it is shown, not typed.
                    value: !recipients[index].receivesRemainder
                        ? recipients[index].amount
                        : preparedAmounts.length > index
                        ? NumberFormat('#,##0').format(preparedAmounts[index])
                        : '…',
                    hint: context.loc.coreScreensAmountLabel,
                    suffixText: recipients[index].receivesRemainder
                        ? context.loc.sendSats
                        : inputCurrency,
                    style: context.bullType.body,
                    onlyNumbers: true,
                    focusNode: focusNodes[recipients[index].id],
                    disabled: recipients[index].receivesRemainder,
                  ),
          ),
        const Gap(12),
        Row(
          children: [
            Expanded(child: Text(context.loc.sendRestGoesTo, style: muted)),
            // Wide enough that "Recipient 3" keeps clear of the dropdown button.
            SizedBox(
              width: 200,
              child: BullDropdown<int>(
                value: remainderId ?? -1,
                items: [
                  if (!isSweep)
                    BullPickerItem(value: -1, label: context.loc.sendRestNone),
                  for (var index = 0; index < recipients.length; index++)
                    BullPickerItem(
                      value: recipients[index].id,
                      label: context.loc.sendRecipientNumber(index + 1),
                    ),
                ],
                onChanged: (value) {
                  if (value == -1) {
                    if (remainderId != null) {
                      onRemainderChanged(remainderId, false);
                    }
                  } else {
                    onRemainderChanged(value, true);
                  }
                },
              ),
            ),
          ],
        ),
        // Only when nobody takes the rest does it stay behind as change.
        if (!isSweep && !hasRemainder) ...[
          const Gap(4),
          Text(context.loc.sendRestChangeHint, style: muted),
        ],
        const Gap(BullSpacing.md),
        _AmountSummaryRow(
          label: context.loc.sendToRecipients,
          value: totalRecipients,
          amountBuilder: amountBuilder,
        ),
        _AmountSummaryRow(
          label: context.loc.sendEstimatedNetworkFee,
          value: fee,
          amountBuilder: amountBuilder,
        ),
        const Gap(BullSpacing.xs),
        Divider(height: 1, color: context.appColors.border),
        const Gap(BullSpacing.xs),
        _AmountSummaryRow(
          label: context.loc.sendTotal,
          value: totalDebited,
          amountBuilder: amountBuilder,
          emphasized: true,
        ),
        if (error case final message?) ...[
          const Gap(8),
          Text(
            message,
            style: muted.copyWith(color: context.appColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// One recipient: number, destination and an optional note on the left, the
/// amount on the right. Every row has the same height and the same amount
/// column, whether it holds a typed amount or the rest.
class _RecipientAmountRow extends StatelessWidget {
  final int number;
  final SendRecipientDraft recipient;
  final SendSource? wallet;
  final String? note;
  final Widget amount;

  const _RecipientAmountRow({
    required this.number,
    required this.recipient,
    required this.wallet,
    required this.note,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final ownWallet = wallet;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: context.appColors.surfaceContainerHighest,
            child: Text(
              '$number',
              style: context.bullType.caption.copyWith(
                color: context.appColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(BullSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ownWallet == null)
                  AddressViewer(
                    recipient.address,
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  )
                else
                  Text(
                    ownWallet.displayLabel(context),
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (note case final text?) ...[
                  const Gap(BullSpacing.xxs),
                  Text(
                    text,
                    style: context.bullType.caption.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(BullSpacing.sm),
          SizedBox(width: 112, child: amount),
        ],
      ),
    );
  }
}

class _AmountSummaryRow extends StatelessWidget {
  const _AmountSummaryRow({
    required this.label,
    required this.value,
    required this.amountBuilder,
    this.emphasized = false,
  });
  final String label;
  final int? value;
  final Widget Function(int amountSat, {bool emphasized}) amountBuilder;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? context.bullType.body.copyWith(fontWeight: FontWeight.w600)
                : context.bullType.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.appColors.textMuted,
                  ),
          ),
        ),
        if (value case final amount?)
          amountBuilder(amount, emphasized: emphasized)
        else
          Text('…', style: context.bullType.label),
      ],
    ),
  );
}
