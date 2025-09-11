import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PaySendPaymentScreen extends StatelessWidget {
  const PaySendPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isConfirmingPayment = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState &&
          (bloc.state as PayPaymentState).isConfirmingPayment,
    );
    final wallet = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).selectedWallet
              : null,
    );
    final order = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).payOrder
              : null,
    );
    final recipient = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).recipient
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
        child: ScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isConfirmingPayment,
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
            const Gap(24.0),
            Text(
              'Confirm payment',
              style: context.font.headlineMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            const Gap(4.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Price will refresh in ',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
                if (order != null)
                  Countdown(
                    until: order.confirmationDeadline,
                    onTimeout: () {
                      log.info('Confirmation deadline reached');
                      context.read<PayBloc>().add(
                        const PayEvent.pollOrderStatus(),
                      );
                    },
                  ),
              ],
            ),

            const Gap(8.0),
            _DetailRow(
              title: 'Order number',
              value: order?.orderNumber.toString(),
              copyValue: order?.orderNumber.toString(),
            ),
            _DetailRow(
              title: 'Recipient type',
              value: recipient?.recipientType.displayName,
            ),
            _DetailRow(
              title: 'Recipient name',
              value: recipient?.getRecipientFullName(),
            ),
            _DetailRow(
              title: 'Recipient details',
              value:
                  recipient != null ? _getRecipientInfoValue(recipient) : null,
            ),
            const _Divider(),
            _DetailRow(
              title: 'Payin amount',
              value: order == null ? null : FormatAmount.btc(order.payinAmount),
            ),
            _DetailRow(
              title: 'Payout amount',
              value:
                  order == null
                      ? null
                      : FormatAmount.fiat(
                        order.payoutAmount,
                        order.payoutCurrency,
                      ),
            ),
            _DetailRow(
              title: 'Exchange rate',
              value:
                  order == null
                      ? null
                      : FormatAmount.fiat(
                        order.exchangeRateAmount ??
                            order.payoutAmount / order.payinAmount,
                        order.exchangeRateCurrency ?? order.payoutCurrency,
                      ),
            ),
            const _Divider(),
            _DetailRow(
              title: 'Pay from wallet',
              value:
                  wallet?.label ??
                  (wallet?.isDefault == true
                      ? wallet?.isLiquid == true
                          ? 'Instant payments'
                          : 'Secure Bitcoin wallet'
                      : ''),
            ),
            if (wallet != null && !wallet.isLiquid) ...[
              _DetailRow(
                title: 'Fee Priority',
                value: 'Fastest',
                onTap: () {
                  debugPrint('Tapped Fee Priority');
                },
              ),
            ],
            _DetailRow(
              title: 'Network fees',
              value: context.select((PayBloc bloc) {
                final state = bloc.state;
                if (state is PayPaymentState && state.absoluteFees != null) {
                  return FormatAmount.btc(
                    ConvertAmount.satsToBtc(state.absoluteFees!),
                  );
                }
                return 'Calculating...';
              }),
            ),
            const Spacer(),
            _BottomButtons(
              onContinuePressed: () {
                context.read<PayBloc>().add(
                  const PayEvent.sendPaymentConfirmed(
                    feeSelection: FeeSelection.fastest,
                    customFee: null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _getRecipientInfoValue(Recipient recipient) {
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
  final void Function()? onTap;
  final String? copyValue;

  const _DetailRow({
    required this.title,
    required this.value,
    this.onTap,
    this.copyValue,
  }) : super();

  @override
  Widget build(BuildContext context) {
    final valueColor =
        onTap == null ? context.colour.outlineVariant : context.colour.primary;

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
                    child:
                        onTap == null
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    value!,
                                    textAlign: TextAlign.end,
                                    maxLines: 2,
                                    style: context.font.bodyMedium?.copyWith(
                                      color: valueColor,
                                    ),
                                  ),
                                ),
                                if (copyValue != null) ...[
                                  const Gap(8),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: copyValue!),
                                      );
                                      SnackBarUtils.showCopiedSnackBar(context);
                                    },
                                    child: Icon(
                                      Icons.copy,
                                      color: context.colour.primary,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ],
                            )
                            : GestureDetector(
                              onTap: onTap,
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      value!,
                                      textAlign: TextAlign.end,
                                      maxLines: 2,
                                      style: context.font.bodyMedium?.copyWith(
                                        color: valueColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: valueColor,
                                    size: 20,
                                  ),
                                ],
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

class _BottomButtons extends StatelessWidget {
  final VoidCallback onContinuePressed;

  const _BottomButtons({required this.onContinuePressed}) : super();

  @override
  Widget build(BuildContext context) {
    final isConfirmingPayment = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState &&
          (bloc.state as PayPaymentState).isConfirmingPayment,
    );
    final wallet = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).selectedWallet
              : null,
    );
    return Column(
      children: [
        const _PayError(),
        if (wallet != null && !wallet.isLiquid) ...[
          BBButton.big(
            label: 'Advanced Settings',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.colour.secondaryFixed,
                constraints: const BoxConstraints(maxWidth: double.infinity),
                useSafeArea: true,
                builder:
                    (BuildContext buildContext) => BlocProvider.value(
                      value: context.read<PayBloc>(),
                      child: const PayAdvancedOptionsBottomSheet(),
                    ),
              );
            },
            bgColor: Colors.transparent,
            textColor: context.colour.secondary,
            outlined: true,
            borderColor: context.colour.secondary,
          ),
          const Gap(16),
        ],
        BBButton.big(
          label: 'Continue',
          disabled: isConfirmingPayment,
          onPressed: onContinuePressed,
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
      ],
    );
  }
}

class _PayError extends StatelessWidget {
  const _PayError();

  @override
  Widget build(BuildContext context) {
    final payError = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState
              ? (bloc.state as PayPaymentState).error
              : null,
    );

    return Center(
      child: switch (payError) {
        AboveMaxAmountPayError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'You are trying to pay above the maximum amount that can be paid with this wallet.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        BelowMinAmountPayError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'You are trying to pay below the minimum amount that can be paid with this wallet.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        InsufficientBalancePayError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'Insufficient balance in the selected wallet to complete this pay order.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        UnexpectedPayError(:final message) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            message,
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
