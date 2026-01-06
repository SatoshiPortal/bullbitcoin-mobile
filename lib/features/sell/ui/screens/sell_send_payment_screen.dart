import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
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
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            const Gap(24.0),
            Text(
              context.loc.sellConfirmPayment,
              style: context.font.headlineMedium?.copyWith(
                color: context.appColors.secondary,
              ),
            ),
            const Gap(4.0),
            Row(
              mainAxisAlignment: .center,
              children: [
                Text(
                  context.loc.sellPriceWillRefreshIn,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.outline,
                  ),
                ),
                if (order != null)
                  Countdown(
                    until: order.confirmationDeadline,
                    onTimeout: () {
                      context.read<SellBloc>().add(
                        const SellEvent.orderRefreshTimePassed(),
                      );
                    },
                  ),
              ],
            ),

            const Gap(8.0),
            _DetailRow(
              title: context.loc.sellOrderNumber,
              value: order?.orderNumber.toString(),
              copyValue: order?.orderNumber.toString(),
            ),
            _DetailRow(
              title: context.loc.sellPayoutRecipient,
              value: switch (order?.payoutMethod) {
                OrderPaymentMethod.cadBalance => context.loc.sellCadBalance,
                OrderPaymentMethod.crcBalance => context.loc.sellCrcBalance,
                OrderPaymentMethod.eurBalance => context.loc.sellEurBalance,
                OrderPaymentMethod.usdBalance => context.loc.sellUsdBalance,
                OrderPaymentMethod.mxnBalance => context.loc.sellMxnBalance,
                OrderPaymentMethod.arsBalance => context.loc.sellArsBalance,
                OrderPaymentMethod.copBalance => context.loc.sellCopBalance,
                _ => order?.payoutMethod.name,
              },
            ),
            const _Divider(),
            _DetailRow(
              title: context.loc.sellPayinAmount,
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
              title: context.loc.sellPayoutAmount,
              value:
                  order == null
                      ? null
                      : FormatAmount.fiat(
                        order.payoutAmount,
                        order.payoutCurrency,
                      ),
            ),
            _DetailRow(
              title: context.loc.sellExchangeRate,
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
              title: context.loc.sellPayFromWallet,
              value:
                  wallet?.label ??
                  (wallet?.isDefault == true
                      ? wallet?.isLiquid == true
                          ? context.loc.sellInstantPayments
                          : context.loc.sellSecureBitcoinWallet
                      : ''),
            ),
            if (wallet != null && !wallet.isLiquid) ...[
              _DetailRow(
                title: context.loc.sellFeePriority,
                value: context.loc.sellFastest,
                onTap: () {
                  debugPrint('Tapped Fee Priority');
                },
              ),
            ],
            // TODO: Implement fee selection
            _DetailRow(
              title: context.loc.sellSendPaymentNetworkFees,
              value: context.select((SellBloc bloc) {
                final state = bloc.state;
                if (state is SellPaymentState && state.absoluteFees != null) {
                  return bitcoinUnit == BitcoinUnit.btc
                      ? FormatAmount.btc(
                        ConvertAmount.satsToBtc(state.absoluteFees!),
                      )
                      : FormatAmount.sats(state.absoluteFees!);
                }
                return context.loc.sellCalculating;
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
                      color: context.appColors.onSurfaceVariant,
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
                                      color: context.appColors.secondary,
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
            label: context.loc.sellAdvancedSettings,
            onPressed: () {
              BlurredBottomSheet.show(
                context: context,
                child: BlocProvider.value(
                  value: context.read<SellBloc>(),
                  child: const SellAdvancedOptionsBottomSheet(),
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
          label: context.loc.sellSendPaymentContinue,
          disabled: isConfirmingPayment,
          onPressed: onContinuePressed,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
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

    if (sellError == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Text(
          sellError.toTranslated(context),
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
