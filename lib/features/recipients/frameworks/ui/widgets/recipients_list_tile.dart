import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_type_text.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/material.dart';

class RecipientsListTile extends StatelessWidget {
  final RecipientViewModel recipient;
  final bool selected;
  final void Function() onTap;

  const RecipientsListTile({
    super.key,
    required this.recipient,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = recipient.displayName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? context.appColors.primary
                : context.appColors.surface,
          ),
          color: context.appColors.onSecondary,
        ),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .center,
              children: [
                Expanded(
                  child: Text(
                    name ?? '-',
                    style: context.font.headlineLarge?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                ),
                RadioGroup<bool>(
                  groupValue: selected,
                  onChanged: (_) => onTap(),
                  child: Radio<bool>(
                    value: true,
                    activeColor: context.appColors.primary,
                    materialTapTargetSize: .shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            RecipientTypeText(
              recipientType: recipient.type,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.secondary,
              ),
            ),
            switch (recipient.type) {
              RecipientType.interacEmailCad => _InfoRow(
                label: context.loc.recipientsInfoEmail,
                value: recipient.email,
              ),
              RecipientType.billPaymentCad => Column(
                crossAxisAlignment: .start,
                children: [
                  _InfoRow(
                    label: context.loc.recipientsInfoPayee,
                    value: recipient.payeeName,
                  ),
                  _InfoRow(
                    label: context.loc.recipientsFieldAccountNumber,
                    value: recipient.payeeAccountNumber,
                  ),
                ],
              ),
              RecipientType.bankTransferCad => _InfoRow(
                label: context.loc.recipientsInfoAccount,
                value:
                    '${recipient.institutionNumber ?? ''}-${recipient.transitNumber ?? ''}-${recipient.accountNumber ?? ''}',
              ),
              RecipientType.sepaEur => _InfoRow(
                label: context.loc.recipientsFieldIban,
                value: recipient.iban,
              ),
              RecipientType.speiClabeMxn => _InfoRow(
                label: context.loc.recipientsFieldClabe,
                value: recipient.clabe,
              ),
              RecipientType.speiSmsMxn => _InfoRow(
                label: context.loc.recipientsInfoPhone,
                value: recipient.phoneNumber,
              ),
              RecipientType.speiCardMxn => _InfoRow(
                label: context.loc.recipientsInfoCard,
                value: recipient.debitcard,
              ),
              RecipientType.sinpeIbanUsd => _InfoRow(
                label: context.loc.recipientsFieldIban,
                value: recipient.iban,
              ),
              RecipientType.sinpeIbanCrc => _InfoRow(
                label: context.loc.recipientsFieldIban,
                value: recipient.iban,
              ),
              RecipientType.sinpeMovilCrc => _InfoRow(
                label: context.loc.recipientsInfoPhone,
                value: recipient.phoneNumber,
              ),
              RecipientType.bankAccountArgentina => _InfoRow(
                label: context.loc.recipientsFieldCvuCbu,
                value: recipient.bankAccount,
              ),
              RecipientType.pseColombia => _InfoRow(
                label: context.loc.recipientsFieldAccountNumber,
                value: recipient.bankAccount,
              ),
              RecipientType.nequiColombia => _InfoRow(
                label: context.loc.recipientsInfoPhone,
                value: recipient.phoneNumber,
              ),
            },
            if (recipient.label != null)
              _InfoRow(
                label: context.loc.recipientsInfoLabel,
                value: recipient.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: ${value != null && value!.isNotEmpty ? value : '-'}',
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.secondary,
        ),
      ),
    );
  }
}
