import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
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
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  const Gap(24.0),
                  Text(
                    'Confirm withdrawal',
                    style: context.font.headlineMedium?.copyWith(
                      color: context.appColors.secondary,
                    ),
                  ),
                  const Gap(4.0),
                  const Gap(8.0),
                  _DetailRow(
                    title: 'Recipient name',
                    value: recipient?.displayName,
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

  String _getRecipientInfoLabel(RecipientViewModel? recipient) {
    if (recipient == null) return 'Bank account';

    switch (recipient.type) {
      case RecipientType.interacEmailCad:
        return 'Email';
      case RecipientType.billPaymentCad:
        return 'Payee';
      case RecipientType.bankTransferCad:
        return 'Account';
      case RecipientType.sepaEur:
        return 'IBAN';
      case RecipientType.speiClabeMxn:
        return 'CLABE';
      case RecipientType.speiSmsMxn:
        return 'Phone';
      case RecipientType.speiCardMxn:
        return 'Card';
      case RecipientType.sinpeIbanUsd:
        return 'IBAN';
      case RecipientType.sinpeIbanCrc:
        return 'IBAN';
      case RecipientType.sinpeMovilCrc:
        return 'Phone';
      case RecipientType.cbuCvuArgentina:
        return 'Account'; // TODO: Update when implemented
      case RecipientType.pseColombia:
        return 'Bank Account';
      case RecipientType.nequiColombia:
        return 'Phone';
    }
  }

  String? _getRecipientInfoValue(RecipientViewModel? recipient) {
    if (recipient == null) return null;

    switch (recipient.type) {
      case RecipientType.interacEmailCad:
        return recipient.email;
      case RecipientType.billPaymentCad:
        return recipient.payeeName ??
            recipient.payeeCode ??
            recipient.payeeAccountNumber;
      case RecipientType.bankTransferCad:
        return '${recipient.institutionNumber}-${recipient.transitNumber}-${recipient.accountNumber}';
      case RecipientType.sepaEur:
        return recipient.iban;
      case RecipientType.speiClabeMxn:
        return recipient.clabe;
      case RecipientType.speiSmsMxn:
        return recipient.phoneNumber;
      case RecipientType.speiCardMxn:
        return recipient.debitcard;
      case RecipientType.sinpeIbanUsd:
        return recipient.iban;
      case RecipientType.sinpeIbanCrc:
        return recipient.iban;
      case RecipientType.sinpeMovilCrc:
        return recipient.phoneNumber;
      case RecipientType.cbuCvuArgentina:
        return null; // TODO: Implement
      case RecipientType.pseColombia:
        return recipient.bankAccount;
      case RecipientType.nequiColombia:
        return recipient.phoneNumber;
    }
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
                      color: context.appColors.surfaceContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.outlineVariant,
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
    return Divider(color: context.appColors.secondaryFixedDim, height: 1);
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
              color: context.appColors.error,
            ),
          ),
          const Gap(16),
        ],
        const Gap(16),
        BBButton.big(
          label: 'Confirm withdrawal',
          disabled: isConfirmingWithdrawal,
          onPressed: onConfirmPressed,
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
        ),
      ],
    );
  }
}
