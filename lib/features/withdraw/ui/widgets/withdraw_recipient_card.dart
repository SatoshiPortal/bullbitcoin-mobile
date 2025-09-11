import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class WithdrawRecipientCard extends StatelessWidget {
  final Recipient recipient;
  final bool selected;
  final void Function() onTap;

  const WithdrawRecipientCard({
    super.key,
    required this.recipient,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = recipient.getRecipientFullName();

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
                    name,
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
            Text(
              recipient.recipientType.displayName,
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            _buildAccountInfo(context, recipient),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(BuildContext context, Recipient recipient) {
    return recipient.when(
      interacEmailCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            name,
            email,
            securityQuestion,
            securityAnswer,
            isDefault,
            defaultComment,
            firstname,
            lastname,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'Email', email),
      billPaymentCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(
            context,
            'Payee',
            payeeName ?? payeeCode ?? payeeAccountNumber,
          ),
      bankTransferCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            institutionNumber,
            transitNumber,
            accountNumber,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(
            context,
            'Account',
            '$institutionNumber-$transitNumber-$accountNumber',
          ),
      sepaEur:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            iban,
            address,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'IBAN', iban),
      speiClabeMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            clabe,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'CLABE', clabe),
      speiSmsMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            phone,
            phoneNumber,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'Phone', phoneNumber),
      speiCardMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            debitCard,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'Card', debitCard),
      sinpeIbanUsd:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            iban,
            ownerName,
            currency,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'IBAN', iban),
      sinpeIbanCrc:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            iban,
            ownerName,
            currency,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'IBAN', iban),
      sinpeMovilCrc:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            phoneNumber,
            ownerName,
            currency,
            defaultComment,
            isCorporate,
            corporateName,
          ) => _buildInfoRow(context, 'Phone', phoneNumber),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
