import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
                (wallet.isLiquid
                    ? context.loc.walletNameInstantPayments
                    : context.loc.walletNameSecureBitcoin)
            : '';

    final counterpartWallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.counterpartWallet,
    );
    final counterpartWalletLabel =
        counterpartWallet != null
            ? counterpartWallet.label ??
                (counterpartWallet.isLiquid == true
                    ? context.loc.walletNameInstantPayments
                    : context.loc.walletNameSecureBitcoin)
            : '';
    final addressLabels =
        transaction?.walletTransaction?.toAddressLabels?.join(', ') ?? '';
    final isOrder = transaction?.isOrder ?? false;
    final walletTransaction = transaction?.walletTransaction;
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );

    final swap = transaction?.swap;
    final toAddress = swap?.receiveAddress ?? transaction?.toAddress;
    final payjoin = transaction?.payjoin;
    final order = transaction?.order;
    final txFee = walletTransaction?.feeSat;

    final amountSent = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.getAmountSent(),
    );
    final amountReceived = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.getAmountReceived(),
    );
    final swapCounterpartTxId = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.swapCounterpartTxId,
    );
    return DetailsTable(
      items: [
        if (txId != null)
          DetailsTableItem(
            label: context.loc.transactionDetailLabelTransactionId,
            displayValue: StringFormatting.truncateMiddle(txId),
            copyValue: txId,
            displayWidget: GestureDetector(
              onTap: () async {
                await launchUrl(Uri.parse(mempoolUrl!));
              },
              child: Text(
                StringFormatting.truncateMiddle(txId),
                style: TextStyle(color: context.appColors.primary),
                textAlign: .end,
              ),
            ),
          ),

        if (labels.isNotEmpty) TransactionNotesTableItem(notes: labels),
        if (walletLabel.isNotEmpty)
          DetailsTableItem(
            label:
                transaction?.isIncoming == true
                    ? context.loc.transactionDetailLabelToWallet
                    : context.loc.transactionDetailLabelFromWallet,
            displayValue: walletLabel,
          ),
        if (counterpartWalletLabel.isNotEmpty)
          DetailsTableItem(
            label:
                transaction?.isOutgoing == true
                    ? context.loc.transactionDetailLabelToWallet
                    : context.loc.transactionDetailLabelFromWallet,
            displayValue: counterpartWalletLabel,
          ),
        if (toAddress != null)
          DetailsTableItem(
            label:
                swap != null &&
                        swap.receiveAddress != null &&
                        swap.receiveAddress!.isNotEmpty
                    ? context.loc.transactionDetailLabelRecipientAddress
                    : context.loc.transactionDetailLabelAddress,
            displayValue: StringFormatting.truncateMiddle(toAddress),
            copyValue: toAddress,
          ),
        if (addressLabels.isNotEmpty)
          DetailsTableItem(
            label: context.loc.transactionDetailLabelAddressNotes,
            displayValue: addressLabels,
          ),
        // TODO(kumulynja): Make the value of the DetailsTableItem be a widget instead of a string
        // to be able to use the CurrencyText widget instead of having to format the amount here.
        if (!isOrder)
          DetailsTableItem(
            label:
                transaction?.isIncoming == true
                    ? context.loc.transactionDetailLabelAmountReceived
                    : context.loc.transactionDetailLabelAmountSent,
            displayValue:
                bitcoinUnit == BitcoinUnit.sats
                    ? FormatAmount.sats(
                      transaction?.isIncoming == true
                          ? amountReceived
                          : amountSent,
                    ).toUpperCase()
                    : FormatAmount.btc(
                      ConvertAmount.satsToBtc(
                        transaction?.isIncoming == true
                            ? amountReceived
                            : amountSent,
                      ),
                    ).toUpperCase(),
          ),
        if (walletTransaction != null) ...[
          if (walletTransaction.isToSelf == true)
            DetailsTableItem(
              label: context.loc.transactionDetailLabelAmountReceived,
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(amountReceived).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(amountReceived),
                      ).toUpperCase(),
            ),
          if (transaction?.isOutgoing == true && swap == null)
            DetailsTableItem(
              label: context.loc.transactionDetailLabelTransactionFee,
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(txFee ?? 0).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(txFee ?? 0),
                      ).toUpperCase(),
            ),
          DetailsTableItem(
            label: context.loc.transactionDetailLabelStatus,
            displayValue: walletTransaction.status.displayName(context),
          ),
          if (walletTransaction.confirmationTime != null)
            DetailsTableItem(
              label: context.loc.transactionDetailLabelConfirmationTime,
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
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
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
                  label: context.loc.transactionDetailLabelPayoutAmount,
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
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),

                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is SellOrder) {
              final payinAmountSat = ConvertAmount.btcToSats(order.payinAmount);
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(payinAmountSat).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(payinAmountSat),
                          ).toUpperCase(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is FiatPaymentOrder) {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                if (order.referenceNumber != null)
                  DetailsTableItem(
                    label: context.loc.transactionOrderLabelReferenceNumber,
                    displayValue: order.referenceNumber,
                    copyValue: order.referenceNumber,
                  ),
                if (order.originName != null)
                  DetailsTableItem(
                    label: context.loc.transactionOrderLabelOriginName,
                    displayValue: order.originName,
                  ),
                if (order.originCedula != null)
                  DetailsTableItem(
                    label: context.loc.transactionOrderLabelOriginCedula,
                    displayValue: order.originCedula,
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is FundingOrder) {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is WithdrawOrder) {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is RewardOrder) {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is RefundOrder) {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else if (order is BalanceAdjustmentOrder) {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.orderType.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.value,
                ),
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: DateFormat(
                    'MMM d, y, h:mm a',
                  ).format(order.createdAt),
                ),
                if (order.completedAt != null)
                  DetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: DateFormat(
                      'MMM d, y, h:mm a',
                    ).format(order.completedAt!),
                  ),
              ];
            } else {
              return [
                DetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order?.orderType.value,
                ),
              ];
            }
          })(),
        ],
        // Transfer info
        if (swap != null) ...[
          DetailsTableItem(
            label:
                swap.isChainSwap
                    ? context.loc.transactionDetailLabelTransferId
                    : context.loc.transactionDetailLabelSwapId,
            displayValue: swap.id,
            copyValue: swap.id,
          ),
          DetailsTableItem(
            label:
                swap.isChainSwap
                    ? context.loc.transactionDetailLabelTransferStatus
                    : context.loc.transactionDetailLabelSwapStatus,
            displayValue:
                (swap.isChainSwap && (swap as ChainSwap).refundTxid != null ||
                        swap.isLnSendSwap &&
                            (swap as LnSendSwap).refundTxid != null)
                    ? context.loc.transactionDetailLabelRefunded
                    : swap.status.displayName(context),
            expandableChild: BBText(
              swap.getDisplayMessage(context),
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.secondary,
              ),
              maxLines: 5,
            ),
          ),
          if (swap is LnSendSwap &&
              swap.preimage != null &&
              swap.preimage!.isNotEmpty)
            DetailsTableItem(
              label: context.loc.transactionLabelPreimage,
              displayValue: StringFormatting.truncateMiddle(
                swap.preimage!,
                head: 6,
                tail: 6,
              ),
              copyValue: swap.preimage,
            ),
          if (swapCounterpartTxId != null)
            DetailsTableItem(
              label:
                  counterpartWallet?.isLiquid == true
                      ? context.loc.transactionDetailLabelLiquidTxId
                      : context.loc.transactionDetailLabelBitcoinTxId,
              displayValue: StringFormatting.truncateMiddle(
                swapCounterpartTxId,
              ),
              copyValue: swapCounterpartTxId,
            ),
          if (swap.fees != null) ...[
            if (swap.isChainSwap) ...[
              DetailsTableItem(
                label: context.loc.transactionLabelSendAmount,
                displayValue:
                    bitcoinUnit == BitcoinUnit.sats
                        ? FormatAmount.sats(
                          (swap as ChainSwap).paymentAmount,
                        ).toUpperCase()
                        : FormatAmount.btc(
                          ConvertAmount.satsToBtc(
                            (swap as ChainSwap).paymentAmount,
                          ),
                        ).toUpperCase(),
              ),
              if (swap.receieveAmount != null)
                DetailsTableItem(
                  label: context.loc.transactionLabelReceiveAmount,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(
                            swap.receieveAmount!,
                          ).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(swap.receieveAmount!),
                          ).toUpperCase(),
                ),
              if (swap.fees!.lockupFee != null)
                DetailsTableItem(
                  label: context.loc.transactionLabelSendNetworkFees,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(
                            swap.fees!.lockupFee!,
                          ).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(swap.fees!.lockupFee!),
                          ).toUpperCase(),
                ),
            ] else if (swap.isLnSendSwap) ...[
              DetailsTableItem(
                label: context.loc.transactionLabelSendAmount,
                displayValue:
                    bitcoinUnit == BitcoinUnit.sats
                        ? FormatAmount.sats(
                          (swap as LnSendSwap).paymentAmount,
                        ).toUpperCase()
                        : FormatAmount.btc(
                          ConvertAmount.satsToBtc(
                            (swap as LnSendSwap).paymentAmount,
                          ),
                        ).toUpperCase(),
              ),
              if (swap.receieveAmount != null)
                DetailsTableItem(
                  label: context.loc.transactionLabelReceiveAmount,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(
                            swap.receieveAmount!,
                          ).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(swap.receieveAmount!),
                          ).toUpperCase(),
                ),
              if (swap.fees!.lockupFee != null)
                DetailsTableItem(
                  label: context.loc.transactionLabelSendNetworkFees,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(
                            swap.fees!.lockupFee!,
                          ).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(swap.fees!.lockupFee!),
                          ).toUpperCase(),
                ),
            ] else if (swap.isLnReceiveSwap) ...[
              if (swap.sendAmount != null)
                DetailsTableItem(
                  label: context.loc.transactionLabelSendAmount,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(swap.sendAmount!).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(swap.sendAmount!),
                          ).toUpperCase(),
                ),
              if (swap.receieveAmount != null)
                DetailsTableItem(
                  label: context.loc.transactionLabelReceiveAmount,
                  displayValue:
                      bitcoinUnit == BitcoinUnit.sats
                          ? FormatAmount.sats(
                            swap.receieveAmount!,
                          ).toUpperCase()
                          : FormatAmount.btc(
                            ConvertAmount.satsToBtc(swap.receieveAmount!),
                          ).toUpperCase(),
                ),
            ],
          ],
          if (swap.fees != null)
            DetailsTableItem(
              label:
                  swap.type.isChain
                      ? context.loc.transactionDetailLabelTransferFees
                      : context.loc.transactionDetailLabelSwapFees,
              displayValue:
                  bitcoinUnit == BitcoinUnit.sats
                      ? FormatAmount.sats(
                        swap.isLnReceiveSwap
                            ? swap.fees!.totalFees(swap.amountSat)
                            : swap.fees!.totalFeesMinusLockup(swap.amountSat),
                      ).toUpperCase()
                      : FormatAmount.btc(
                        ConvertAmount.satsToBtc(
                          swap.isLnReceiveSwap
                              ? swap.fees!.totalFees(swap.amountSat)
                              : swap.fees!.totalFeesMinusLockup(swap.amountSat),
                        ),
                      ).toUpperCase(),
              expandableChild: Column(
                children: [
                  const Gap(4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BBText(
                      swap.isLnReceiveSwap
                          ? context.loc.transactionFeesDeductedFrom
                          : context.loc.transactionFeesTotalDeducted,
                      style: context.font.labelSmall,
                      color: context.appColors.surfaceContainer,
                    ),
                  ),
                  if (swap.isLnReceiveSwap && swap.fees!.lockupFee != null)
                    _feeRow(
                      context,
                      context.loc.transactionDetailLabelSendNetworkFee,
                      swap.fees!.lockupFee!,
                    ),
                  if (swap.fees!.claimFee != null)
                    _feeRow(
                      context,
                      context.loc.transactionLabelReceiveNetworkFee,
                      swap.fees!.claimFee!,
                    ),
                  if (swap.fees!.serverNetworkFees != null)
                    _feeRow(
                      context,
                      context.loc.transactionLabelServerNetworkFees,
                      swap.fees!.serverNetworkFees!,
                    ),
                  _feeRow(
                    context,
                    context.loc.transactionDetailLabelTransferFee,
                    swap.fees?.boltzFee ?? 0,
                  ),
                  const Gap(4),
                ],
              ),
            ),
          DetailsTableItem(
            label: context.loc.transactionDetailLabelCreatedAt,
            displayValue: DateFormat(
              'MMM d, y, h:mm a',
            ).format(swap.creationTime),
          ),
          if (swap.completionTime != null)
            DetailsTableItem(
              label: context.loc.transactionDetailLabelCompletedAt,
              displayValue: DateFormat(
                'MMM d, y, h:mm a',
              ).format(swap.completionTime!),
            ),
        ],
        if (payjoin != null) ...[
          DetailsTableItem(
            label: context.loc.transactionDetailLabelPayjoinStatus,
            displayValue:
                payjoin.isCompleted ||
                        (payjoin.status == PayjoinStatus.proposed &&
                            walletTransaction != null)
                    ? context.loc.transactionDetailLabelPayjoinCompleted
                    : payjoin.isExpired
                    ? context.loc.transactionDetailLabelPayjoinExpired
                    : payjoin.status.name,
          ),
          DetailsTableItem(
            label: context.loc.transactionDetailLabelPayjoinCreationTime,
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
          color: context.appColors.surfaceContainer,
        ),
        const Spacer(),
        CurrencyText(
          amt,
          showFiat: false,
          style: context.font.bodySmall,
          color: context.appColors.surfaceContainer,
        ),
      ],
    ),
  );
}
