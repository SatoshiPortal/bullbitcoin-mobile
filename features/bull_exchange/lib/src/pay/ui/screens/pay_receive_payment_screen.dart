import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;
import 'package:bull_exchange/src/pay/presentation/pay_failure_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/payout_rail_l10n.dart';

import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/src/pay/ui/widgets/pay_qr_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullInvoiceViewer,
        BullButton,
        BullCountdown,
        BullCopyField,
        BullPaymentPreparationView,
        BullSnackBar,
        BullText,
        BullTopBar,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class PayReceivePaymentScreen extends StatelessWidget {
  const PayReceivePaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((PayBloc bloc) => bloc.state);

    final preparation = context.select(
      (PayBloc bloc) => bloc.state is PayPreparingPaymentState
          ? bloc.state as PayPreparingPaymentState
          : null,
    );
    if (preparation != null) {
      return BullPaymentPreparationView(
        title: context.loc.payPleasePayInvoice,
        detailLabels: [
          context.loc.payDepositAddress,
          context.loc.payPayinAmount,
          context.loc.payPayoutAmount,
        ],
        errorMessage: preparation.error?.toTranslated(context),
        onBack: () => context.read<PayBloc>().add(
          const PayEvent.paymentPreparationAbandoned(),
        ),
      );
    }

    if (state is! PayPaymentState) {
      return Scaffold(body: Center(child: Text(context.loc.payInvalidState)));
    }

    final order = state.payOrder;
    final recipient = state.selectedRecipient;
    // For now, we'll use BTC as default unit since PayPaymentState doesn't have bitcoinUnit
    const bitcoinUnit = BitcoinUnit.btc;
    // Get bip21InvoiceData from the state
    final bip21InvoiceData = state.bip21InvoiceData;

    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<PayBloc>().add(
            const PayEvent.paymentPreparationAbandoned(),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            title: '',
            titleWidget: Image.asset(
              context.read<ExchangePayinUi>().brandAsset,
              height: 32,
              width: 32,
            ),
            onBack: context.pop,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Center(
                child: BullText(
                  context.loc.payPleasePayInvoice,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.secondary,
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: .center,
                  children: [
                    BullText(
                      context.loc.payPriceRefreshIn,
                      style: context.bullType.body,
                      color: context.appColors.outline,
                    ),
                    if (order.confirmationDeadline case final deadline?)
                      BullCountdown(until: deadline),
                  ],
                ),
              ),
              const Gap(32),
              BullCopyField(
                copyLabel: context.loc.copyDialogButton,
                copiedMessage: context.loc.copiedToClipboard,
                text: bitcoinUnit == BitcoinUnit.btc
                    ? FormatAmount.btc(order.payinAmount)
                    : FormatAmount.sats(
                        ConvertAmount.btcToSats(order.payinAmount),
                      ),
              ),
              const Gap(32),
              _buildPaymentInput(context, order),
              const Gap(32),
              Container(
                height: 1,
                width: double.infinity,
                color: context.appColors.secondaryFixedDim,
              ),
              const Gap(16),
              _buildDetailRow(
                context,
                context.loc.payRecipientType,
                recipient.rail.label(context),
              ),
              const Gap(8),
              _buildDetailRow(
                context,
                context.loc.payRecipientName,
                recipient.displayName ?? '-',
              ),
              const Gap(8),
              _buildDetailRow(
                context,
                switch (recipient.accountRows) {
                  [final row, ...] => row.field.label(context),
                  [] => context.loc.recipientsInfoAccount,
                },
                recipient.accountRows.firstOrNull?.value ??
                    context.loc.payNoDetailsAvailable,
              ),
              const Gap(8),
              _buildDetailRow(
                context,
                context.loc.payBitcoinAmount,
                bitcoinUnit == BitcoinUnit.btc
                    ? FormatAmount.btc(order.payinAmount)
                    : FormatAmount.sats(
                        ConvertAmount.btcToSats(order.payinAmount),
                      ),
              ),
              const Gap(8),
              _buildDetailRow(
                context,
                context.loc.payPayoutAmount,
                FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
              ),
              const Gap(8),
              _buildDetailRow(
                context,
                context.loc.payBitcoinPrice,
                FormatAmount.fiat(
                  order.exchangeRateAmount ??
                      order.payoutAmount / order.payinAmount,
                  order.exchangeRateCurrency ?? order.payoutCurrency,
                ),
              ),
              const Gap(8),
              _buildDetailRow(
                context,
                context.loc.payOrderNumber,
                order.orderNumber.toString(),
                copyValue: order.orderNumber.toString(),
              ),
              const Gap(48),
              Row(
                children: [
                  Expanded(
                    child: BullButton.secondary(
                      label: context.loc.payCopyInvoice,
                      onPressed: () {
                        if (bip21InvoiceData.isNotEmpty) {
                          Clipboard.setData(
                            ClipboardData(text: bip21InvoiceData),
                          );
                          BullSnackBar.show(
                            context,
                            message: context.loc.copiedToClipboard,
                          );
                        }
                      },
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: BullButton.secondary(
                      label: context.loc.payShowQrCode,
                      onPressed: () {
                        PayQrBottomSheet.show(context, bip21InvoiceData);
                      },
                    ),
                  ),
                ],
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
    String? copyValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          BullText(
            label,
            style: context.bullType.body.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Row(
              mainAxisAlignment: .end,
              children: [
                Flexible(
                  child: BullText(
                    value,
                    textAlign: .end,
                    maxLines: 2,
                    style: context.bullType.body.copyWith(
                      color: isError
                          ? context.appColors.error
                          : context.appColors.secondary,
                    ),
                  ),
                ),
                if (copyValue != null) ...[
                  const Gap(8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copyValue));
                      BullSnackBar.show(
                        context,
                        message: context.loc.copiedToClipboard,
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      color: context.appColors.primary,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInput(BuildContext context, FiatPaymentOrder order) {
    final fullText = switch (order.payinMethod) {
      OrderPaymentMethod.bitcoin => order.bitcoinAddress ?? '',
      OrderPaymentMethod.liquid => order.liquidAddress ?? '',
      OrderPaymentMethod.lnInvoice => order.lightningInvoice ?? '',
      _ => '',
    };

    return order.payinMethod == OrderPaymentMethod.lnInvoice
        ? BullInvoiceViewer(
            fullText,
            title: context.loc.invoiceViewerTitle,
            copyLabel: context.loc.viewerTapToCopy,
            copiedMessage: context.loc.copiedToClipboard,
          )
        : context.read<ExchangePayinUi>().addressViewer(context, fullText);
  }
}
