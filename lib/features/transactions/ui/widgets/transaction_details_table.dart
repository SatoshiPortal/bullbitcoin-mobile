import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/mempool_url.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_notes_table_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailsTable extends StatelessWidget {
  const TransactionDetailsTable({super.key});

  @override
  Widget build(BuildContext context) {
    final transaction = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.transaction,
    );
    final txId = transaction?.txId;
    final isTestnet = transaction?.isTestnet ?? false;
    final isLiquid = transaction?.isLiquid ?? false;
    final mempoolUrl =
        txId != null
            ? isLiquid
                ? MempoolUrl.liquidTxidUrl(
                  transaction?.walletTransaction?.unblindedUrl ?? '',
                  isTestnet: isTestnet,
                )
                : MempoolUrl.bitcoinTxidUrl(txId, isTestnet: isTestnet)
            : null;
    final labels = transaction?.labels ?? [];
    final wallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.wallet,
    );
    final walletLabel =
        wallet != null
            ? wallet.label ??
                (wallet.isLiquid ? 'Instant Payments' : 'Secure Bitcoin')
            : '';

    final counterpartWallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.counterpartWallet,
    );
    final counterpartWalletLabel =
        counterpartWallet != null
            ? counterpartWallet.label ??
                (counterpartWallet.isLiquid == true
                    ? 'Instant Payments'
                    : 'Secure Bitcoin')
            : '';
    final toAddress = transaction?.toAddress;
    final addressLabels =
        transaction?.walletTransaction?.toAddressLabels?.join(', ') ?? '';
    final amountSat = transaction?.amountSat;
    final isOrder = transaction?.isOrder ?? false;
    final walletTransaction = transaction?.walletTransaction;
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );

    final swap = transaction?.swap;
    final payjoin = transaction?.payjoin;
    final order = transaction?.order;

    final swapFees =
        (swap?.fees?.claimFee ?? 0) +
        (swap?.fees?.boltzFee ?? 0) +
        (swap?.fees?.lockupFee ?? 0);
    final swapCounterpartTxId = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.swapCounterpartTxId,
    );

    return DetailsTable(
      items: [
        if (txId != null)
          DetailsTableItem(
            label: 'Transaction ID',
            displayValue: StringFormatting.truncateMiddle(txId),
            copyValue: txId,
            displayWidget: GestureDetector(
              onTap: () async {
                await launchUrl(Uri.parse(mempoolUrl!));
              },
              child: Text(
                StringFormatting.truncateMiddle(txId),
                style: TextStyle(color: context.colour.primary),
                textAlign: TextAlign.end,
              ),
            ),
          ),

        if (labels.isNotEmpty) TransactionNotesTableItem(notes: labels),
        if (walletLabel.isNotEmpty)
          DetailsTableItem(
            label:
                transaction?.isIncoming == true ? 'To wallet' : 'From wallet',
            displayValue: walletLabel,
          ),
        if (counterpartWalletLabel.isNotEmpty)
          DetailsTableItem(
            label:
                transaction?.isOutgoing == true ? 'To wallet' : 'From wallet',
            displayValue: counterpartWalletLabel,
          ),
        if (toAddress != null)
          DetailsTableItem(
            label:
                swap?.receiveAddress != null && swap!.receiveAddress!.isNotEmpty
                    ? 'Recipient Address'
                    : 'Address',
            displayValue: StringFormatting.truncateMiddle(toAddress),
            copyValue: toAddress,
          ),
        if (addressLabels.isNotEmpty)
          DetailsTableItem(label: 'Address notes', displayValue: addressLabels),
        // TODO(kumulynja): Make the value of the DetailsTableItem be a widget instead of a string
        // to be able to use the CurrencyText widget instead of having to format the amount here.
        if (!isOrder)
          DetailsTableItem(
            label:
                transaction?.isIncoming == true
                    ? 'Amount received'
                    : 'Amount sent',
            displayValue:
                bitcoinUnit == BitcoinUnit.sats
                    ? FormatAmount.sats(amountSat ?? 0).toUpperCase()
                    : FormatAmount.btc(
                      ConvertAmount.satsToBtc(amountSat ?? 0),
                    ).toUpperCase(),
          ),
        if (walletTransaction != null) ...[
          if (walletTransaction.isToSelf == true)
            DetailsTableItem(
              label: 'Amount received',
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(amountSat ?? 0).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(amountSat ?? 0),
                      ).toUpperCase(),
            ),
          if (transaction?.isOutgoing == true)
            DetailsTableItem(
              label: 'Transaction Fee',
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(
                        walletTransaction.feeSat,
                      ).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(walletTransaction.feeSat),
                      ).toUpperCase(),
            ),
          DetailsTableItem(
            label: 'Status',
            displayValue: walletTransaction.status.displayName,
          ),
          if (walletTransaction.confirmationTime != null)
            DetailsTableItem(
              label: 'Confirmation time',
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(walletTransaction.confirmationTime!),
            ),
        ],
        // Order info
        if (transaction?.isOrder == true) ...[
          ...(() {
            if (order is BuyOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      order.payinCurrency == 'LBTC' ||
                              order.payinCurrency == 'BTC'
                          ? bitcoinUnit == BitcoinUnit.sats
                              ? FormatAmount.sats(
                                ConvertAmount.btcToSats(order.payinAmount),
                              )
                              : FormatAmount.btc(order.payinAmount)
                          : '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue:
                      order.payoutCurrency == 'LBTC' ||
                              order.payoutCurrency == 'BTC'
                          ? bitcoinUnit == BitcoinUnit.sats
                              ? FormatAmount.sats(
                                ConvertAmount.btcToSats(order.payoutAmount),
                              )
                              : FormatAmount.btc(order.payoutAmount)
                          : '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is SellOrder) {
              final payinAmountSat = ConvertAmount.btcToSats(order.payinAmount);
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(payinAmountSat).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(payinAmountSat),
                          ).toUpperCase(),
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is FiatPaymentOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),

                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is FundingOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is WithdrawOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is RewardOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is RefundOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is BalanceAdjustmentOrder) {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: 'Order Number',
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: 'Payin amount',
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: 'Payout amount',
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: 'Exchange rate',
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: 'Payin method',
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payout method',
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: 'Payin Status',
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: 'Order Status',
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: 'Payout Status',
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: 'Created at',
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: 'Completed at',
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else {
              return [
                DetailsTableItem(
                  label: 'Order Type',
                  displayValue: order?.orderType.value,
                ),
              ];
            }
          })(),
        ],
        // Swap info
        if (swap != null) ...[
          DetailsTableItem(
            label: 'Swap ID',
            displayValue: swap.id,
            copyValue: swap.id,
          ),
          DetailsTableItem(
            label: 'Swap status',
            displayValue:
                (swap.isChainSwap && (swap as ChainSwap).refundTxid != null ||
                        swap.isLnSendSwap &&
                            (swap as LnSendSwap).refundTxid != null)
                    ? 'Refunded'
                    : swap.status.displayName,
            expandableChild: BBText(
              swap.getDisplayMessage(),
              style: context.font.bodySmall?.copyWith(
                color: context.colour.secondary,
              ),
              maxLines: 5,
            ),
          ),
          if (swapCounterpartTxId != null)
            DetailsTableItem(
              label:
                  counterpartWallet?.isLiquid == true
                      ? 'Liquid transaction ID'
                      : 'Bitcoin transaction ID',
              displayValue: StringFormatting.truncateMiddle(
                swapCounterpartTxId,
              ),
              copyValue: swapCounterpartTxId,
            ),
          if (swap.fees != null)
            DetailsTableItem(
              label: 'Total Swap fees',
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(swapFees).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(swapFees),
                      ).toUpperCase(),
              expandableChild: Column(
                children: [
                  const Gap(4),

                  _feeRow(
                    context,
                    'Network Fee',
                    (swap.fees?.lockupFee ?? 0) + (swap.fees?.claimFee ?? 0),
                  ),

                  _feeRow(context, 'Boltz Swap Fee', swap.fees?.boltzFee ?? 0),
                  const Gap(4),
                ],
              ),
            ),
          DetailsTableItem(
            label: 'Created at',
            displayValue: DateFormat(
              'MMM d, y, h:mm a',
            ).format(swap.creationTime),
          ),
          if (swap.completionTime != null)
            DetailsTableItem(
              label: 'Completed at',
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(swap.completionTime!),
            ),
        ],
        if (payjoin != null) ...[
          DetailsTableItem(
            label: 'Payjoin status',
            displayValue:
                payjoin.isCompleted ||
                        (payjoin.status == PayjoinStatus.proposed &&
                            walletTransaction != null)
                    ? 'Completed'
                    : payjoin.isExpired
                    ? 'Expired'
                    : payjoin.status.name,
          ),
          DetailsTableItem(
            label: 'Payjoin creation time',
            displayValue: DateFormat(
              'MMM d, y, h:mm a',
            ).format(payjoin.createdAt),
          ),
        ],
      ],
    );
  }
}

Widget _feeRow(BuildContext context, String label, int amt) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        BBText(
          label,
          style: context.font.bodySmall,
          color: context.colour.surfaceContainer,
        ),
        const Spacer(),
        CurrencyText(
          amt,
          showFiat: false,
          style: context.font.bodySmall,
          color: context.colour.surfaceContainer,
        ),
      ],
    ),
  );
}
