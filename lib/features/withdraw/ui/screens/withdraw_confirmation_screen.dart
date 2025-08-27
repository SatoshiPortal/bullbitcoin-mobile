import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class WithdrawConfirmationScreen extends StatelessWidget {
  const WithdrawConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState
              ? (bloc.state as WithdrawConfirmationState).order
              : null,
    );

    final recipient = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState
              ? (bloc.state as WithdrawConfirmationState).recipient
              : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          Assets.logos.bbLogoSmall.path,
          height: 32,
          width: 32,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: context.select<WithdrawBloc, bool>(
                (bloc) =>
                    bloc.state is WithdrawConfirmationState &&
                    (bloc.state as WithdrawConfirmationState)
                        .isConfirmingWithdrawal,
              ),
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  const Gap(24.0),
                  Text(
                    'Confirm withdrawal',
                    style: context.font.headlineMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                  const Gap(4.0),
                  const Gap(8.0),
                  _DetailRow(
                    title: 'Recipient name',
                    value: recipient?.getRecipientFullName(),
                  ),
                  const _Divider(),
                  _DetailRow(
                    title: _getRecipientInfoLabel(recipient),
                    value: _getRecipientInfoValue(recipient),
                  ),
                  const _Divider(),
                  _DetailRow(
                    title: 'Amount',
                    value:
                        order == null
                            ? null
                            : FormatAmount.fiat(
                              order.payoutAmount,
                              order.payoutCurrency,
                            ),
                  ),
                  const Spacer(),
                  _ConfirmButton(
                    onConfirmPressed: () {
                      context.read<WithdrawBloc>().add(
                        const WithdrawEvent.confirmed(),
                      );
                    },
                  ),
                  const Gap(24.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRecipientInfoLabel(Recipient? recipient) {
    if (recipient == null) return 'Bank account';

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
          ) => 'Email',
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
          ) => 'Payee',
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
          ) => 'Account',
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
          ) => 'IBAN',
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
          ) => 'CLABE',
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
          ) => 'Phone',
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
          ) => 'Card',
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
          ) => 'IBAN',
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
          ) => 'IBAN',
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
          ) => 'Phone',
    );
  }

  String? _getRecipientInfoValue(Recipient? recipient) {
    if (recipient == null) return null;

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
          ) => email,
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
          ) => payeeName ?? payeeCode ?? payeeAccountNumber,
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
          ) => '$institutionNumber-$transitNumber-$accountNumber',
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
          ) => iban,
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
          ) => clabe,
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
          ) => phoneNumber,
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
          ) => debitCard,
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
          ) => iban,
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
          ) => iban,
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
          ) => phoneNumber,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String? value;

  const _DetailRow({required this.title, required this.value}) : super();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child:
          value == null
              ? const LoadingLineContent()
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.surfaceContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: context.colour.secondaryFixedDim, height: 1);
  }
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onConfirmPressed;

  const _ConfirmButton({required this.onConfirmPressed}) : super();

  @override
  Widget build(BuildContext context) {
    final isConfirmingWithdrawal = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState &&
          (bloc.state as WithdrawConfirmationState).isConfirmingWithdrawal,
    );
    final withdrawError = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawConfirmationState
              ? (bloc.state as WithdrawConfirmationState).error
              : null,
    );

    return Column(
      children: [
        if (withdrawError != null) ...[
          Text(
            'Error: $withdrawError',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
          ),
          const Gap(16),
        ],
        const Gap(16),
        BBButton.big(
          label: 'Confirm withdrawal',
          disabled: isConfirmingWithdrawal,
          onPressed: onConfirmPressed,
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}
