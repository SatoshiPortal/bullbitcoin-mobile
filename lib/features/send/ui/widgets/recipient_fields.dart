import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, BullSwitch, Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecipientAddressFields extends StatelessWidget {
  final List<SendRecipientDraft> recipients;
  final Widget primaryField;
  final ValueChanged<int> onRemoveRecipient;
  final Future<void> Function(int id, String value) onAddressChanged;

  const RecipientAddressFields({
    super.key,
    required this.recipients,
    required this.primaryField,
    required this.onRemoveRecipient,
    required this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          recipients.length > 1
              ? context.loc.sendRecipientAddressNumber(1)
              : context.loc.sendRecipientAddress,
          style: context.font.bodyMedium,
          color: context.appColors.secondary,
        ),
        const Gap(16),
        primaryField,
        for (var index = 1; index < recipients.length; index++) ...[
          const Gap(16),
          Row(
            children: [
              Expanded(
                child: BBText(
                  context.loc.sendRecipientAddressNumber(index + 1),
                  style: context.font.bodyMedium,
                  color: context.appColors.secondary,
                ),
              ),
              IconButton(
                tooltip: context.loc.sendRemoveRecipient,
                onPressed: () => onRemoveRecipient(recipients[index].id),
                icon: Icon(
                  Icons.close,
                  color: context.appColors.secondary,
                  size: 20,
                ),
              ),
            ],
          ),
          BullInputText(
            key: ValueKey('send-recipient-address-${recipients[index].id}'),
            onChanged: (value) => onAddressChanged(recipients[index].id, value),
            value: recipients[index].address,
            hint: context.loc.sendPasteAddressOrInvoice,
            maxLines: 1,
            rightIcon: Icon(
              Icons.paste_sharp,
              color: context.appColors.secondary,
              size: 20,
            ),
            onRightTap: () async {
              final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
              if (clipboard == null || !context.mounted) return;
              await onAddressChanged(
                recipients[index].id,
                clipboard.text ?? '',
              );
            },
          ),
          if (recipients[index].address.isNotEmpty &&
              !recipients[index].isValid) ...[
            const Gap(6),
            BBText(
              context.loc.sendErrorInvalidAddressOrInvoice,
              style: context.font.bodySmall,
              color: context.appColors.error,
            ),
          ],
        ],
      ],
    );
  }
}

class AddRecipientButton extends StatelessWidget {
  final bool canAdd;
  final Future<void> Function() onAdd;

  const AddRecipientButton({
    super.key,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (!canAdd) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(context.loc.sendAddRecipient),
        ),
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
  });

  @override
  Widget build(BuildContext context) {
    final remainderRecipientId = recipients
        .where((recipient) => recipient.receivesRemainder)
        .firstOrNull
        ?.id;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < recipients.length; index++) ...[
          BorderedTappableTile(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BBText(
                        context.loc.sendRecipientNumber(index + 1),
                        style: context.font.titleMedium,
                        color: context.appColors.secondary,
                      ),
                    ),
                    if (index > 0)
                      IconButton(
                        tooltip: context.loc.sendRemoveRecipient,
                        onPressed: () =>
                            onRemoveRecipient(recipients[index].id),
                        icon: Icon(
                          Icons.close,
                          color: context.appColors.secondary,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const Gap(8),
                AddressViewer(
                  recipients[index].address,
                  style: context.font.bodyMedium,
                  color: context.appColors.secondary,
                ),
                const Gap(16),
                BullInputText(
                  key: ValueKey(
                    'send-recipient-amount-${recipients[index].id}',
                  ),
                  onChanged: (value) =>
                      onAmountChanged(recipients[index].id, value),
                  value: recipients[index].receivesRemainder
                      ? context.loc.sendRemaining
                      : recipients[index].amount,
                  hint: context.loc.coreScreensAmountLabel,
                  fixedPrefix: inputCurrency,
                  onlyNumbers: true,
                  focusNode: focusNodes[recipients[index].id],
                  disabled: recipients[index].receivesRemainder,
                ),
                if (recipients[index].receivesRemainder) ...[
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: preparedAmounts.length > index
                        ? amountBuilder(preparedAmounts[index])
                        : BBText(
                            '…',
                            style: context.font.bodyMedium,
                            color: context.appColors.textMuted,
                          ),
                  ),
                ],
                const Gap(12),
                _RemainingBalanceControl(
                  recipientId: recipients[index].id,
                  value: recipients[index].receivesRemainder,
                  isSweep: isSweep,
                  onChanged: (value) =>
                      onRemainderChanged(recipients[index].id, value),
                ),
              ],
            ),
          ),
          if (index < recipients.length - 1) const Gap(12),
        ],
        if (error != null) ...[
          const Gap(8),
          BBText(
            error!,
            style: context.font.bodySmall,
            color: context.appColors.error,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
    if (!isSweep) return content;
    return RadioGroup<int>(
      groupValue: remainderRecipientId,
      onChanged: (recipientId) {
        if (recipientId != null) {
          onRemainderChanged(recipientId, true);
        }
      },
      child: content,
    );
  }
}

class _RemainingBalanceControl extends StatelessWidget {
  final int recipientId;
  final bool value;
  final bool isSweep;
  final ValueChanged<bool> onChanged;

  const _RemainingBalanceControl({
    required this.recipientId,
    required this.value,
    required this.isSweep,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBText(
            context.loc.sendRemainingBalance,
            style: context.font.bodyMedium,
            color: context.appColors.secondary,
          ),
        ),
        if (isSweep)
          Radio<int>(
            value: recipientId,
            activeColor: context.appColors.secondary,
          )
        else
          BullSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
