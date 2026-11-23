import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart'
    show AddressViewer, FullScreenScannerPage;
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/wallet/public/recipient_wallet.dart'
    show Wallet, WalletCards;
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDropdown,
        BullPickerItem,
        BullInputText,
        BullPaymentDestinationInput,
        BullTypographyX,
        Gap;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class RecipientAddressFields extends StatelessWidget {
  final List<SendRecipientDraft> recipients;
  final Widget primaryField;
  final bool multipleRecipients;
  final Map<int, Wallet> internalRecipientWallets;
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
              scanLabel: context.loc.spScan,
              clearLabel: context.loc.spClearButton,
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
  final Wallet? wallet;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
      color: context.appColors.surface,
      border: Border(
        bottom: BorderSide(color: context.appColors.border),
        left: switch (wallet) {
          final ownWallet? => BorderSide(
            color: WalletCards.cardDetails(context, ownWallet),
            width: 6,
          ),
          null => BorderSide.none,
        },
      ),
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
  final Map<int, Wallet> internalRecipientWallets;
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
  final Widget Function(int amountSat) amountBuilder;

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
                style: context.bullType.body,
              ),
            ),
            ?amountHeader,
          ],
        ),
        for (var index = 0; index < recipients.length; index++) ...[
          Builder(
            builder: (context) {
              final recipient = recipients[index];
              final wallet = internalRecipientWallets[recipient.id];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  border: Border(
                    bottom: BorderSide(color: context.appColors.border),
                    left: wallet == null
                        ? BorderSide.none
                        : BorderSide(
                            color: WalletCards.cardDetails(context, wallet),
                            width: 6,
                          ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (wallet != null) const Gap(8),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              context.appColors.surfaceContainerHighest,
                          child: Text(
                            '${index + 1}',
                            style: context.bullType.caption.copyWith(
                              color: context.appColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: wallet == null
                              ? AddressViewer(
                                  recipient.address,
                                  style: context.bullType.body,
                                )
                              : Text(
                                  wallet.displayLabel(context),
                                  style: context.bullType.body.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        const Gap(8),
                        SizedBox(
                          width: 150,
                          child:
                              !recipient.receivesRemainder &&
                                  amountFieldBuilder != null
                              ? Semantics(
                                  label: context.loc.sendRecipientNumber(
                                    index + 1,
                                  ),
                                  child: amountFieldBuilder?.call(
                                    recipient,
                                    focusNodes[recipient.id],
                                  ),
                                )
                              : BullInputText(
                                  key: ValueKey(
                                    'send-recipient-amount-${recipient.id}',
                                  ),
                                  onChanged: (value) =>
                                      onAmountChanged(recipient.id, value),
                                  value: recipient.receivesRemainder
                                      ? context.loc.sendRemaining
                                      : recipient.amount,
                                  hint: context.loc.coreScreensAmountLabel,
                                  suffixText: inputCurrency,
                                  style: context.bullType.body,
                                  onlyNumbers: true,
                                  focusNode: focusNodes[recipient.id],
                                  disabled: recipient.receivesRemainder,
                                ),
                        ),
                      ],
                    ),
                    if (recipient.receivesRemainder) ...[
                      const Gap(4),
                      Row(
                        children: [
                          Text(context.loc.sendRestCalculated, style: muted),
                          const Spacer(),
                          if (preparedAmounts.length > index)
                            amountBuilder(preparedAmounts[index])
                          else
                            Text('…', style: muted),
                        ],
                      ),
                    ] else if (qrAmountRecipientIds.contains(recipient.id)) ...[
                      const Gap(4),
                      Text(context.loc.sendAmountFromQrEditable, style: muted),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: Text(
                context.loc.sendRestGoesTo,
                style: context.bullType.body,
              ),
            ),
            SizedBox(
              width: 160,
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
        if (!isSweep) ...[
          const Gap(4),
          Text(context.loc.sendRestChangeHint, style: muted),
        ],
        const Gap(12),
        Divider(height: 1, color: context.appColors.border),
        const Gap(8),
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
        _AmountSummaryRow(
          label: context.loc.sendTotalDebited,
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

class _AmountSummaryRow extends StatelessWidget {
  const _AmountSummaryRow({
    required this.label,
    required this.value,
    required this.amountBuilder,
    this.emphasized = false,
  });
  final String label;
  final int? value;
  final Widget Function(int amountSat) amountBuilder;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? context.bullType.body.copyWith(fontWeight: FontWeight.w500)
                : context.bullType.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.appColors.textMuted,
                  ),
          ),
        ),
        if (value case final amount?)
          amountBuilder(amount)
        else
          Text('…', style: context.bullType.label),
      ],
    ),
  );
}
