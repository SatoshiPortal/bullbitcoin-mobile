import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
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
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SellSendPaymentScreen extends StatelessWidget {
  const SellSendPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isConfirmingPayment = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState &&
          (bloc.state as SellPaymentState).isConfirmingPayment,
    );
    final wallet = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).selectedWallet
              : null,
    );
    final bitcoinUnit = context.select((SellBloc bloc) {
      final state = bloc.state;
      if (state is SellPaymentState) return state.bitcoinUnit;
      return BitcoinUnit.btc;
    });
    final order = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).sellOrder
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
                      context.read<SellBloc>().add(
                        const SellEvent.orderRefreshTimePassed(),
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
              title: 'Payout recipient',
              value: switch (order?.payoutMethod) {
                OrderPaymentMethod.cadBalance => 'CAD Balance',
                OrderPaymentMethod.crcBalance => 'CRC Balance',
                OrderPaymentMethod.eurBalance => 'EUR Balance',
                OrderPaymentMethod.usdBalance => 'USD Balance',
                OrderPaymentMethod.mxnBalance => 'MXN Balance',
                _ => order?.payoutMethod.name,
              },
            ),
            const _Divider(),
            _DetailRow(
              title: 'Payin amount',
              value:
                  order == null
                      ? null
                      : bitcoinUnit == BitcoinUnit.btc
                      ? FormatAmount.btc(order.payinAmount)
                      : FormatAmount.sats(
                        ConvertAmount.btcToSats(order.payinAmount),
                      ),
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
            // TODO: Implement fee selection
            _DetailRow(
              title: 'Network fees',
              value: context.select((SellBloc bloc) {
                final state = bloc.state;
                if (state is SellPaymentState && state.absoluteFees != null) {
                  return bitcoinUnit == BitcoinUnit.btc
                      ? FormatAmount.btc(
                        ConvertAmount.satsToBtc(state.absoluteFees!),
                      )
                      : FormatAmount.sats(state.absoluteFees!);
                }
                return 'Calculating...';
              }),
            ),
            const Spacer(),
            _BottomButtons(
              onContinuePressed: () {
                context.read<SellBloc>().add(
                  const SellEvent.sendPaymentConfirmed(
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
      (SellBloc bloc) =>
          bloc.state is SellPaymentState &&
          (bloc.state as SellPaymentState).isConfirmingPayment,
    );
    final wallet = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).selectedWallet
              : null,
    );
    return Column(
      children: [
        const _SellError(),
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
                      value: context.read<SellBloc>(),
                      child: const SellAdvancedOptionsBottomSheet(),
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

class _SellError extends StatelessWidget {
  const _SellError();

  @override
  Widget build(BuildContext context) {
    final sellError = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).error
              : null,
    );

    return Center(
      child: switch (sellError) {
        AboveMaxAmountSellError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'You are trying to sell above the maximum amount that can be sold with this wallet.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        BelowMinAmountSellError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'You are trying to sell below the minimum amount that can be sold with this wallet.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        InsufficientBalanceSellError _ => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'Insufficient balance in the selected wallet to complete this sell order.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        UnexpectedSellError(:final message) => Padding(
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
