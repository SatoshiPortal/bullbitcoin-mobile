import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/recipient_type_text.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';

class RecipientsListTile extends StatelessWidget {
  final RecipientViewModel recipient;
  final bool selected;
  final VoidCallback? onTap;

  const RecipientsListTile({
    super.key,
    required this.recipient,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = recipient.displayName;

    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        enabled: onTap != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: BullBorderedTile(
            onTap: onTap,
            backgroundColor: selected ? context.bull.surfaceContainer : null,
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name ?? '-',
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Gap(8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: selected
                          ? BullIcon(
                              BullIcons.checkCircle,
                              color: context.bull.primary,
                            )
                          : null,
                    ),
                  ],
                ),
                const Gap(8),
                RecipientTypeText(
                  recipientType: recipient.type,
                  style: context.bullType.body,
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
                  RecipientType.sepaEur ||
                  RecipientType.confidentialSepaEur => _InfoRow(
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
        '$label: ${value?.isNotEmpty == true ? value : '-'}',
        style: context.bullType.body,
      ),
    );
  }
}
