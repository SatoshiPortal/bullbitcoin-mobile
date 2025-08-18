import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_qr_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SellReceivePaymentScreen extends StatelessWidget {
  const SellReceivePaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).sellOrder
              : null,
    );
    final bitcoinUnit = context.select((SellBloc bloc) {
      final state = bloc.state;
      if (state is SellPaymentState) return state.bitcoinUnit;
      return BitcoinUnit.btc;
    });
    final bip21InvoiceData = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState
              ? (bloc.state as SellPaymentState).bip21InvoiceData
              : '',
    );

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: '',
          bullLogo: true,
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: BBText(
                'Please pay this invoice',
                style: context.font.headlineMedium,
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BBText(
                    'Price will refresh in ',
                    style: context.font.bodyMedium,
                    color: context.colour.outline,
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
            ),
            const Gap(32),
            if (order == null)
              const LoadingLineContent()
            else
              CopyInput(
                text:
                    bitcoinUnit == BitcoinUnit.btc
                        ? FormatAmount.btc(order.payinAmount)
                        : FormatAmount.sats(
                          ConvertAmount.btcToSats(order.payinAmount),
                        ),
              ),
            const Gap(32),
            if (order == null)
              const LoadingLineContent()
            else
              _buildPaymentInput(context, order),
            const Gap(32),
            Container(
              height: 1,
              width: double.infinity,
              color: context.colour.secondaryFixedDim,
            ),
            const Gap(16),
            _buildDetailRow(
              context,
              'Payout recipient',
              order == null
                  ? 'Loading...'
                  : switch (order.payoutMethod) {
                    OrderPaymentMethod.cadBalance => 'CAD Balance',
                    OrderPaymentMethod.crcBalance => 'CRC Balance',
                    OrderPaymentMethod.eurBalance => 'EUR Balance',
                    OrderPaymentMethod.usdBalance => 'USD Balance',
                    OrderPaymentMethod.mxnBalance => 'MXN Balance',
                    _ => order.payoutMethod.name,
                  },
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Bitcoin amount',
              order == null
                  ? 'Loading...'
                  : bitcoinUnit == BitcoinUnit.btc
                  ? FormatAmount.btc(order.payinAmount)
                  : FormatAmount.sats(
                    ConvertAmount.btcToSats(order.payinAmount),
                  ),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Payout amount',
              order == null
                  ? 'Loading...'
                  : FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Bitcoin Price',
              order == null
                  ? 'Loading...'
                  : FormatAmount.fiat(
                    order.exchangeRateAmount ??
                        order.payoutAmount / order.payinAmount,
                    order.exchangeRateCurrency ?? order.payoutCurrency,
                  ),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Order Number',
              order?.orderNumber.toString() ?? 'Loading...',
              copyValue: order?.orderNumber.toString(),
            ),
            const Gap(48),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: 'Copy invoice',
                    onPressed: () {
                      if (bip21InvoiceData.isNotEmpty) {
                        Clipboard.setData(
                          ClipboardData(text: bip21InvoiceData),
                        );
                        SnackBarUtils.showCopiedSnackBar(context);
                      }
                    },
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    label: 'Show QR code',
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                    onPressed: () {
                      SellQrBottomSheet.show(context, bip21InvoiceData);
                    },
                  ),
                ),
              ],
            ),
            const Gap(40),
          ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: BBText(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    style: context.font.bodyMedium?.copyWith(
                      color: isError ? context.colour.error : null,
                    ),
                  ),
                ),
                if (copyValue != null) ...[
                  const Gap(8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copyValue));
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInput(BuildContext context, SellOrder order) {
    final fullText = switch (order.payinMethod) {
      OrderPaymentMethod.bitcoin => order.bitcoinAddress ?? '',
      OrderPaymentMethod.liquid => order.liquidAddress ?? '',
      OrderPaymentMethod.lnInvoice => order.lightningInvoice ?? '',
      _ => '',
    };

    if (order.payinMethod == OrderPaymentMethod.lnInvoice &&
        fullText.length > 20) {
      final displayText =
          '${fullText.substring(0, 36)}...${fullText.substring(fullText.length - 30)}';
      return CopyInput(text: displayText, clipboardText: fullText);
    }

    return CopyInput(text: fullText);
  }
}
