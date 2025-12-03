import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PaySendPaymentScreen extends StatelessWidget {
  const PaySendPaymentScreen({super.key});

  String _formatSinpePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return 'N/A';

    // Remove any existing formatting
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add +506 prefix
    final String formattedNumber = '+506$cleanNumber';

    // Add dashes every 4 digits after the prefix
    if (cleanNumber.length >= 4) {
      const String prefix = '+506';
      final String number = cleanNumber;
      final StringBuffer formatted = StringBuffer(prefix);

      for (int i = 0; i < number.length; i += 4) {
        final int end = (i + 4 < number.length) ? i + 4 : number.length;
        formatted.write('-${number.substring(i, end)}');
      }

      return formatted.toString();
    }

    return formattedNumber;
  }

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
              ? (bloc.state as PayPaymentState).selectedRecipient
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
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            const Gap(24.0),
            Text(
              context.loc.payConfirmPayment,
              style: context.font.headlineMedium?.copyWith(
                color: context.appColors.secondary,
              ),
            ),
            const Gap(4.0),
            Row(
              mainAxisAlignment: .center,
              children: [
                Text(
                  context.loc.payPriceRefreshIn,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.outline,
                  ),
                ),
                if (order != null)
                  Countdown(
                    until: order.confirmationDeadline,
                    onTimeout: () {
                      context.read<PayBloc>().add(
                        const PayEvent.orderRefreshTimePassed(),
                      );
                    },
                  ),
              ],
            ),

            const Gap(8.0),
            _DetailRow(
              title: context.loc.payOrderNumber,
              value: order?.orderNumber.toString(),
              copyValue: order?.orderNumber.toString(),
            ),
            _DetailRow(
              title: context.loc.payRecipientType,
              value:
                  recipient != null
                      ? switch (recipient.type) {
                        // TODO: Use localization labels instead of hardcoded strings.
                        // CANADA types
                        RecipientType.interacEmailCad => 'Interac e-Transfer',
                        RecipientType.billPaymentCad => 'Bill Payment',
                        RecipientType.bankTransferCad => 'Bank Transfer',
                        // EUROPE types
                        RecipientType.sepaEur => 'SEPA Transfer',
                        // MEXICO types
                        RecipientType.speiClabeMxn => 'SPEI CLABE',
                        RecipientType.speiSmsMxn => 'SPEI SMS',
                        RecipientType.speiCardMxn => 'SPEI Card',
                        // COSTA RICA types
                        RecipientType.sinpeIbanUsd => 'SINPE IBAN (USD)',
                        RecipientType.sinpeIbanCrc => 'SINPE IBAN (CRC)',
                        RecipientType.sinpeMovilCrc => 'SINPE Móvil',
                        // ARGENTINA types
                        RecipientType.cbuCvuArgentina => 'CBU/CVU Argentina',
                        RecipientType.pseColombia => 'Bank Account COP',
                        RecipientType.nequiColombia => 'Nequi',
                      }
                      : null,
            ),
            _DetailRow(
              title: context.loc.payRecipientName,
              value: recipient?.displayName,
            ),
            _DetailRow(
              title: context.loc.payRecipientDetails,
              value:
                  recipient != null ? _getRecipientInfoValue(recipient) : null,
            ),
            const _Divider(),
            _DetailRow(
              title: context.loc.payPayinAmount,
              value: order == null ? null : FormatAmount.btc(order.payinAmount),
            ),
            _DetailRow(
              title: context.loc.payPayoutAmount,
              value:
                  order == null
                      ? null
                      : FormatAmount.fiat(
                        order.payoutAmount,
                        order.payoutCurrency,
                      ),
            ),
            _DetailRow(
              title: context.loc.payExchangeRate,
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
              title: context.loc.payPayFromWallet,
              value:
                  wallet?.label ??
                  (wallet?.isDefault == true
                      ? wallet?.isLiquid == true
                          ? context.loc.payInstantPayments
                          : context.loc.paySecureBitcoinWallet
                      : ''),
            ),
            if (wallet != null && !wallet.isLiquid) ...[
              _DetailRow(
                title: context.loc.payFeePriority,
                value: context.loc.payFastest,
                onTap: () {
                  debugPrint('Tapped Fee Priority');
                },
              ),
            ],
            _DetailRow(
              title: context.loc.payNetworkFees,
              value: context.select((PayBloc bloc) {
                final state = bloc.state;
                if (state is PayPaymentState && state.absoluteFees != null) {
                  return FormatAmount.btc(
                    ConvertAmount.satsToBtc(state.absoluteFees!),
                  );
                }
                return context.loc.payCalculating;
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

  String? _getRecipientInfoValue(RecipientViewModel recipient) {
    switch (recipient.type) {
      case RecipientType.cbuCvuArgentina:
      case RecipientType.pseColombia:
        return recipient.bankAccount;
      case RecipientType.nequiColombia:
        return recipient.phoneNumber;
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
        return _formatSinpePhoneNumber(recipient.phoneNumber);
    }
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
        onTap == null
            ? context.appColors.outlineVariant
            : context.appColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child:
          value == null
              ? const LoadingLineContent()
              : Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(
                    title,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.surfaceContainer,
                    ),
                  ),
                  Expanded(
                    child:
                        onTap == null
                            ? Row(
                              mainAxisAlignment: .end,
                              children: [
                                Flexible(
                                  child: Text(
                                    value!,
                                    textAlign: .end,
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
                                      color: context.appColors.primary,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ],
                            )
                            : GestureDetector(
                              onTap: onTap,
                              behavior: .opaque,
                              child: Row(
                                mainAxisAlignment: .end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      value!,
                                      textAlign: .end,
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
    return Divider(color: context.appColors.secondaryFixedDim, height: 1);
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
            label: context.loc.payAdvancedSettings,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.appColors.secondaryFixed,
                constraints: const BoxConstraints(maxWidth: double.infinity),
                useSafeArea: true,
                builder:
                    (BuildContext buildContext) => BlocProvider.value(
                      value: context.read<PayBloc>(),
                      child: const PayAdvancedOptionsBottomSheet(),
                    ),
              );
            },
            bgColor: context.appColors.transparent,
            textColor: context.appColors.secondary,
            outlined: true,
            borderColor: context.appColors.secondary,
          ),
          const Gap(16),
        ],
        BBButton.big(
          label: context.loc.payContinue,
          disabled: isConfirmingPayment,
          onPressed: onContinuePressed,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
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
            context.loc.payAboveMaxAmount,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: .center,
          ),
        ),
        BelowMinAmountPayError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            context.loc.payBelowMinAmount,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: .center,
          ),
        ),
        InsufficientBalancePayError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            context.loc.payInsufficientBalance,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: .center,
          ),
        ),
        UnexpectedPayError(:final message) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            message,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: .center,
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
