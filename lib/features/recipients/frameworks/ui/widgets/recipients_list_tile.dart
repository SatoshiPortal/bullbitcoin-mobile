import 'package:bb_mobile/core/themes/app_theme.dart';
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
            color: selected ? context.colour.primary : context.colour.surface,
          ),
          color: context.colour.onPrimary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    name ?? '-',
                    style: context.font.headlineLarge?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
                Radio<bool>(
                  value: true,
                  groupValue: selected,
                  onChanged: (_) => onTap(),
                  activeColor: context.colour.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            RecipientTypeText(
              recipientType: recipient.type,
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            switch (recipient.type) {
              RecipientType.interacEmailCad => _InfoRow(
                label: 'Email',
                value: recipient.email,
              ),
              RecipientType.billPaymentCad => _InfoRow(
                label: 'Payee',
                value:
                    recipient.payeeName ??
                    recipient.payeeCode ??
                    recipient.payeeAccountNumber,
              ),
              RecipientType.bankTransferCad => _InfoRow(
                label: 'Account',
                value:
                    '${recipient.institutionNumber ?? ''}-${recipient.transitNumber ?? ''}-${recipient.accountNumber ?? ''}',
              ),
              RecipientType.sepaEur => _InfoRow(
                label: 'IBAN',
                value: recipient.iban,
              ),
              RecipientType.speiClabeMxn => _InfoRow(
                label: 'CLABE',
                value: recipient.clabe,
              ),
              RecipientType.speiSmsMxn => _InfoRow(
                label: 'Phone',
                value: recipient.phoneNumber,
              ),
              RecipientType.speiCardMxn => _InfoRow(
                label: 'Card',
                value: recipient.debitcard,
              ),
              RecipientType.sinpeIbanUsd => _InfoRow(
                label: 'IBAN',
                value: recipient.iban,
              ),
              RecipientType.sinpeIbanCrc => _InfoRow(
                label: 'IBAN',
                value: recipient.iban,
              ),
              RecipientType.sinpeMovilCrc => _InfoRow(
                label: 'Phone',
                value: recipient.phoneNumber,
              ),
              // TODO: Handle this case.
              RecipientType.cbuCvuArgentina => const _InfoRow(
                label: 'CBU/CVU',
                value: null,
              ),
              // TODO: Handle this case.
              RecipientType.pseColombia => const _InfoRow(
                label: 'Account Number',
                value: null,
              ),
            },
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
          color: context.colour.secondary,
        ),
      ),
    );
  }
}
