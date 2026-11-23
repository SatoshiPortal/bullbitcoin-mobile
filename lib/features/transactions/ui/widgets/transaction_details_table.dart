import '../../presentation/wallet_transaction_status_l10n.dart';

import 'package:primitives/primitives.dart' show BitcoinNetwork, LiquidNetwork;
import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:exchange/exchange.dart';
import 'package:swaps/swaps.dart';
import 'package:bb_mobile/features/transactions/presentation/swap_l10n_x.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show ConvertAmount;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:primitives/primitives.dart' show StringFormatting;
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:mempool/mempool.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/order_l10n.dart';
import 'package:bb_mobile/features/transactions/presentation/order_payment_method_l10n.dart';
import 'package:bb_mobile/features/transactions/presentation/order_swap_status_l10n.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/labels_table_item.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmount,
        BullDetailsTable,
        BullDetailsTableItem,
        BullTransactionViewer,
        BullText,
        Gap,
        BullSnackBar,
        bullDateLocale,
        BullTypographyX;
import 'package:intl/intl.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class TransactionDetailsTable extends StatelessWidget {
  const TransactionDetailsTable({super.key});

  Widget _transactionViewer(
    BuildContext context,
    String txId, {
    required primitives.Network network,
    required String? unblindedUrl,
    required String? payjoinFragment,
  }) {
    return BullTransactionViewer(
      txId,
      style: TextStyle(color: context.appColors.primary),
      title: context.loc.transactionViewerTitle,
      copiedMessage: context.loc.copiedToClipboard,
      copyLabel: context.loc.viewerTapToCopy,
      explorerActions: [
        (
          copyLabel: context.loc.viewerCopyLink,
          openLabel: context.loc.viewerViewInExplorer,
          resolveUrl: () async {
            final links = context.read<MempoolLinks>();
            final link = await switch ((network, unblindedUrl)) {
              (final LiquidNetwork liquid, final String path) =>
                links.unblindedTransaction(path, network: liquid),
              _ => links.transaction(txId, network: network),
            };
            return link.fold((uri) => uri.toString(), (_) => null);
          },
        ),
        if (network is BitcoinNetwork && payjoinFragment != null)
          (
            copyLabel: context.loc.viewerCopyLinkDisclosePayjoin,
            openLabel: context.loc.viewerViewInExplorerDisclosePayjoin,
            resolveUrl: () async {
              final link = await context.read<MempoolLinks>().transaction(
                txId,
                network: network,
                fragment: payjoinFragment,
              );
              return link.fold((uri) => uri.toString(), (_) => null);
            },
          ),
      ],
      openUrl: (url) async {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the copy confirmation at the top, like the rest of this screen.
    void showCopied() =>
        BullSnackBar.show(context, message: context.loc.copiedToClipboard);
    final dateTime = DateFormat.yMMMd(bullDateLocale(context)).add_jm();
    final transaction = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.transaction,
    );
    final txId = transaction?.txId;
    final explorerNetwork = transaction?.supportsPublicExplorer == true
        ? transaction?.explorerNetwork
        : null;
    final labels = transaction?.labels ?? [];
    final wallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.wallet,
    );
    final walletLabel = wallet != null ? wallet.displayLabel(context) : '';

    final counterpartWallet = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.counterpartWallet,
    );
    final counterpartWalletLabel = counterpartWallet != null
        ? counterpartWallet.displayLabel(context)
        : '';
    final addressLabels = transaction?.walletTransaction?.toAddressLabels ?? [];
    final isOrder = transaction?.isOrder ?? false;
    final walletTransaction = transaction?.walletTransaction;

    final swap = transaction?.swap;
    final orderSwap = transaction?.orderSwap;
    final toAddress =
        swap?.receiveAddress ??
        transaction?.orderSwapDestinationAddress ??
        transaction?.toAddress;
    final payjoin = transaction?.payjoin;
    final order = transaction?.order;
    final txFee = transaction?.payjoinSenderFeeSat ?? walletTransaction?.feeSat;
    final swapSendNetworkFee = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.swapSendNetworkFeeSat,
    );

    final amountSent = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.getAmountSent(),
    );
    // Null when the sent amount is genuinely unknown (e.g. a recovered swap
    // whose lockup leg isn't linked) — the row is hidden rather than showing 0.
    final displayAmountSent = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.displayAmountSentSat,
    );
    final amountReceived = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.getAmountReceived(),
    );
    final swapCounterpartTxId = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.swapCounterpartTxId,
    );
    // A recovered swap shows only trustworthy figures; the derivation lives in
    // TransactionDetailsState (see Swap.recovered).
    final recovered = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.isRecoveredSwap,
    );
    final recoveredBoltzFee = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.recoveredBoltzFeeSat,
    );
    final recoveredNetworkFee = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.recoveredNetworkFeeSat,
    );
    return BullDetailsTable(
      items: [
        if (txId != null)
          BullDetailsTableItem(
            label: context.loc.transactionDetailLabelTransactionId,
            displayValue: StringFormatting.truncateMiddle(txId),
            copyValue: txId,
            onCopied: showCopied,
            displayWidget: explorerNetwork != null
                ? _transactionViewer(
                    context,
                    txId,
                    network: explorerNetwork,
                    unblindedUrl: walletTransaction?.unblindedUrl,
                    payjoinFragment: transaction?.payjoinOwnershipFragment,
                  )
                : null,
          ),

        if (labels.isNotEmpty && txId != null)
          LabelsTableItem(
            title: context.loc.transactionNotesLabel,
            labels: labels,
          ),
        if (walletLabel.isNotEmpty)
          BullDetailsTableItem(
            label: transaction?.isReceivingWallet(wallet?.id) == true
                ? context.loc.transactionDetailLabelToWallet
                : context.loc.transactionDetailLabelFromWallet,
            displayValue: walletLabel,
          ),
        if (counterpartWalletLabel.isNotEmpty && !recovered)
          BullDetailsTableItem(
            label:
                transaction?.isReceivingWallet(
                      counterpartWallet?.id,
                      isCounterpart: true,
                    ) ==
                    true
                ? context.loc.transactionDetailLabelToWallet
                : context.loc.transactionDetailLabelFromWallet,
            displayValue: counterpartWalletLabel,
          ),
        if (toAddress != null)
          BullDetailsTableItem(
            label:
                swap != null &&
                    swap.receiveAddress != null &&
                    swap.receiveAddress!.isNotEmpty
                ? context.loc.transactionDetailLabelRecipientAddress
                : context.loc.transactionDetailLabelAddress,
            copyValue: toAddress,
            onCopied: showCopied,
            displayWidget: AddressViewer(
              toAddress,
              style: TextStyle(color: context.appColors.onSurface),
            ),
          ),
        if (addressLabels.isNotEmpty && toAddress != null)
          LabelsTableItem(
            title: context.loc.transactionDetailLabelAddressNotes,
            labels: addressLabels,
          ),
        if (!isOrder &&
            (transaction?.isIncoming == true || displayAmountSent != null))
          BullDetailsTableItem(
            label: transaction?.isIncoming == true
                ? context.loc.transactionDetailLabelAmountReceived
                : context.loc.transactionDetailLabelAmountSent,
            displayWidget: BullAmount.signedSats(
              transaction?.isIncoming == true
                  ? amountReceived
                  : (displayAmountSent ?? amountSent),
              interactive: true,
              overrideHideAmounts: true,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.appColors.onSurface,
              textAlign: TextAlign.end,
            ),
          ),
        if (walletTransaction != null) ...[
          if (walletTransaction.isToSelf == true)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelAmountReceived,
              displayWidget: BullAmount.signedSats(
                amountReceived,
                interactive: true,
                overrideHideAmounts: true,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.onSurface,
                textAlign: TextAlign.end,
              ),
            ),
          if (transaction?.isOutgoing == true && transaction?.isSwap != true)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelTransactionFee,
              displayWidget: BullAmount.signedSats(
                txFee ?? 0,
                interactive: true,
                overrideHideAmounts: true,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.onSurface,
                textAlign: TextAlign.end,
              ),
            ),
          BullDetailsTableItem(
            label: context.loc.transactionDetailLabelStatus,
            displayValue: walletTransaction.status.displayName(context),
          ),
          if (walletTransaction.confirmationTime != null)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelConfirmationTime,
              displayValue: dateTime.format(
                walletTransaction.confirmationTime!,
              ),
            ),
        ],
        if (orderSwap != null) ...[
          if (orderSwap.order != null)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelOrderNumber,
              displayValue: orderSwap.order!.orderNumber.toString(),
              copyValue: orderSwap.order!.orderNumber.toString(),
              onCopied: showCopied,
            ),
          BullDetailsTableItem(
            label: context.loc.transactionDetailLabelPayinAmount,
            displayWidget: BullAmount.signedSats(
              orderSwap.order?.payinAmountSat.toInt() ??
                  orderSwap.requestedAmountSat.toInt(),
              interactive: true,
              overrideHideAmounts: true,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.appColors.onSurface,
              textAlign: TextAlign.end,
            ),
          ),
          if (orderSwap.order case final swapOrder?)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelPayoutAmount,
              displayWidget: BullAmount.signedSats(
                swapOrder.payoutAmountSat.toInt(),
                interactive: true,
                overrideHideAmounts: true,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.onSurface,
                textAlign: TextAlign.end,
              ),
            ),
          if (txFee != null)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelTransactionFee,
              displayWidget: BullAmount.signedSats(
                txFee,
                interactive: true,
                overrideHideAmounts: true,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.onSurface,
                textAlign: TextAlign.end,
              ),
            ),
          if (orderSwap.order != null) ...[
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelPayinStatus,
              displayValue: orderSwap.order!.payinStatus
                  .toTranslatedOrderStatus(context),
            ),
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelOrderStatus,
              displayValue: orderSwap.order!.orderStatus
                  .toTranslatedOrderStatus(context),
            ),
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelPayoutStatus,
              displayValue: orderSwap.order!.payoutStatus
                  .toTranslatedOrderStatus(context),
            ),
          ],
        ],
        // Order info
        if (transaction?.isOrder == true) ...[
          ...(() {
            if (order is BuyOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      order.payinCurrency == 'LBTC' ||
                          order.payinCurrency == 'BTC'
                      ? null
                      : '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                  displayWidget:
                      order.payinCurrency == 'LBTC' ||
                          order.payinCurrency == 'BTC'
                      ? BullAmount.signedSats(
                          ConvertAmount.btcToSats(order.payinAmount),
                          interactive: true,
                          overrideHideAmounts: true,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.appColors.onSurface,
                          textAlign: TextAlign.end,
                        )
                      : null,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue:
                      order.payoutCurrency == 'LBTC' ||
                          order.payoutCurrency == 'BTC'
                      ? null
                      : '${order.payoutAmount} ${order.payoutCurrency}',
                  displayWidget:
                      order.payoutCurrency == 'LBTC' ||
                          order.payoutCurrency == 'BTC'
                      ? BullAmount.signedSats(
                          ConvertAmount.btcToSats(order.payoutAmount),
                          interactive: true,
                          overrideHideAmounts: true,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.appColors.onSurface,
                          textAlign: TextAlign.end,
                        )
                      : null,
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),

                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is SellOrder) {
              final payinAmountSat = ConvertAmount.btcToSats(order.payinAmount);
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayWidget: BullAmount.signedSats(
                    payinAmountSat,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is FiatPaymentOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                if (order.paymentDescription != null &&
                    order.paymentDescription!.isNotEmpty)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelPaymentDescription,
                    displayValue: order.paymentDescription,
                  ),
                if (order.recipientToDisplay != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelRecipient,
                    displayValue: order.recipientToDisplay,
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: order.payoutAmountToDisplay,
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                if (order.referenceNumber != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionOrderLabelReferenceNumber,
                    displayValue: order.referenceNumber,
                    copyValue: order.referenceNumber,
                    onCopied: showCopied,
                  ),
                if (order.originName != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionOrderLabelOriginName,
                    displayValue: order.originName,
                  ),
                if (order.originCedula != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionOrderLabelOriginCedula,
                    displayValue: order.originCedula,
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is FundingOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is WithdrawOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is RewardOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      order.payinCurrency == 'LBTC' ||
                          order.payinCurrency == 'BTC'
                      ? null
                      : '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                  displayWidget:
                      order.payinCurrency == 'LBTC' ||
                          order.payinCurrency == 'BTC'
                      ? BullAmount.signedSats(
                          ConvertAmount.btcToSats(order.payinAmount),
                          interactive: true,
                          overrideHideAmounts: true,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.appColors.onSurface,
                          textAlign: TextAlign.end,
                        )
                      : null,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue:
                      order.payoutCurrency == 'LBTC' ||
                          order.payoutCurrency == 'BTC'
                      ? null
                      : '${order.payoutAmount} ${order.payoutCurrency}',
                  displayWidget:
                      order.payoutCurrency == 'LBTC' ||
                          order.payoutCurrency == 'BTC'
                      ? BullAmount.signedSats(
                          ConvertAmount.btcToSats(order.payoutAmount),
                          interactive: true,
                          overrideHideAmounts: true,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.appColors.onSurface,
                          textAlign: TextAlign.end,
                        )
                      : null,
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is RefundOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      order.payinCurrency == 'LBTC' ||
                          order.payinCurrency == 'BTC'
                      ? null
                      : '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                  displayWidget:
                      order.payinCurrency == 'LBTC' ||
                          order.payinCurrency == 'BTC'
                      ? BullAmount.signedSats(
                          ConvertAmount.btcToSats(order.payinAmount),
                          interactive: true,
                          overrideHideAmounts: true,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.appColors.onSurface,
                          textAlign: TextAlign.end,
                        )
                      : null,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue:
                      order.payoutCurrency == 'LBTC' ||
                          order.payoutCurrency == 'BTC'
                      ? null
                      : '${order.payoutAmount} ${order.payoutCurrency}',
                  displayWidget:
                      order.payoutCurrency == 'LBTC' ||
                          order.payoutCurrency == 'BTC'
                      ? BullAmount.signedSats(
                          ConvertAmount.btcToSats(order.payoutAmount),
                          interactive: true,
                          overrideHideAmounts: true,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.appColors.onSurface,
                          textAlign: TextAlign.end,
                        )
                      : null,
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else if (order is BalanceAdjustmentOrder) {
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order.typeLabel(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderNumber,
                  displayValue: order.orderNumber.toString(),
                  copyValue: order.orderNumber.toString(),
                  onCopied: showCopied,
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinAmount,
                  displayValue:
                      '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutAmount,
                  displayValue: '${order.payoutAmount} ${order.payoutCurrency}',
                ),
                if (order.exchangeRateAmount != null &&
                    order.exchangeRateCurrency != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelExchangeRate,
                    displayValue:
                        '${order.exchangeRateAmount} ${order.exchangeRateCurrency}',
                  ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinMethod,
                  displayValue: order.payinMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutMethod,
                  displayValue: order.payoutMethod.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayinStatus,
                  displayValue: order.payinStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderStatus,
                  displayValue: order.orderStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelPayoutStatus,
                  displayValue: order.payoutStatus.toTranslated(context),
                ),
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelCreatedAt,
                  displayValue: dateTime.format(order.createdAt.toLocal()),
                ),
                if (order.completedAt != null)
                  BullDetailsTableItem(
                    label: context.loc.transactionDetailLabelCompletedAt,
                    displayValue: dateTime.format(order.completedAt!.toLocal()),
                  ),
              ];
            } else {
              // Order types with no dedicated section land here, so this must
              // report the server-sent name rather than 'Unknown'.
              return [
                BullDetailsTableItem(
                  label: context.loc.transactionDetailLabelOrderType,
                  displayValue: order?.typeLabel(context),
                ),
              ];
            }
          })(),
        ],
        // Transfer info
        if (swap != null) ...[
          BullDetailsTableItem(
            label: swap.isChainSwap
                ? context.loc.transactionDetailLabelTransferId
                : context.loc.transactionDetailLabelSwapId,
            displayValue: StringFormatting.truncateMiddle(swap.id),
            copyValue: swap.id,
            onCopied: showCopied,
          ),
          BullDetailsTableItem(
            label: swap.isChainSwap
                ? context.loc.transactionDetailLabelTransferStatus
                : context.loc.transactionDetailLabelSwapStatus,
            displayValue:
                (swap.isChainSwap && (swap as ChainSwap).refundTxid != null ||
                    swap.isLnSendSwap &&
                        (swap as LnSendSwap).refundTxid != null)
                ? context.loc.transactionDetailLabelRefunded
                : swap.status.displayName(context),
            expandableChild: BullText(
              swap.getDisplayMessage(context),
              style: context.bullType.label
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(color: context.appColors.secondary),
              maxLines: 5,
            ),
          ),
          if (swap is LnSendSwap &&
              swap.preimage != null &&
              swap.preimage!.isNotEmpty)
            BullDetailsTableItem(
              label: context.loc.transactionLabelPreimage,
              displayValue: StringFormatting.truncateMiddle(
                swap.preimage!,
                head: 6,
                tail: 6,
              ),
              copyValue: swap.preimage,
              onCopied: showCopied,
            ),
          if (swapCounterpartTxId != null)
            BullDetailsTableItem(
              label: counterpartWallet?.isLiquid == true
                  ? context.loc.transactionDetailLabelLiquidTxId
                  : context.loc.transactionDetailLabelBitcoinTxId,
              displayValue: StringFormatting.truncateMiddle(
                swapCounterpartTxId,
              ),
              copyValue: swapCounterpartTxId,
              onCopied: showCopied,
            ),
          if (recovered) ...[
            if (amountSent > 0)
              BullDetailsTableItem(
                label: context.loc.transactionLabelSendAmount,
                displayWidget: BullAmount.signedSats(
                  amountSent,
                  interactive: true,
                  overrideHideAmounts: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.end,
                ),
              ),
            if (amountReceived > 0)
              BullDetailsTableItem(
                label: context.loc.transactionLabelReceiveAmount,
                displayWidget: BullAmount.signedSats(
                  amountReceived,
                  interactive: true,
                  overrideHideAmounts: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.end,
                ),
              ),
            if (recoveredBoltzFee > 0)
              BullDetailsTableItem(
                label: context.loc.transactionDetailLabelTransferFee,
                displayWidget: BullAmount.signedSats(
                  recoveredBoltzFee,
                  interactive: true,
                  overrideHideAmounts: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.end,
                ),
              ),
            if (amountReceived > 0 && recoveredNetworkFee > 0)
              BullDetailsTableItem(
                label: context.loc.transactionLabelNetworkFees,
                displayWidget: BullAmount.signedSats(
                  recoveredNetworkFee,
                  interactive: true,
                  overrideHideAmounts: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.end,
                ),
              ),
          ],
          if (!recovered && swap.fees != null) ...[
            if (swap.isChainSwap) ...[
              BullDetailsTableItem(
                label: context.loc.transactionLabelSendAmount,
                displayWidget: BullAmount.signedSats(
                  (swap as ChainSwap).paymentAmount,
                  interactive: true,
                  overrideHideAmounts: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.end,
                ),
              ),
              if (swap.receieveAmount case final receiveAmount?)
                BullDetailsTableItem(
                  label: context.loc.transactionLabelReceiveAmount,
                  displayWidget: BullAmount.signedSats(
                    receiveAmount,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
              if (swapSendNetworkFee != null)
                BullDetailsTableItem(
                  label: context.loc.transactionLabelSendNetworkFees,
                  displayWidget: BullAmount.signedSats(
                    swapSendNetworkFee,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
            ] else if (swap.isLnSendSwap) ...[
              BullDetailsTableItem(
                label: context.loc.transactionLabelSendAmount,
                displayWidget: BullAmount.signedSats(
                  (swap as LnSendSwap).paymentAmount,
                  interactive: true,
                  overrideHideAmounts: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.onSurface,
                  textAlign: TextAlign.end,
                ),
              ),
              if (swap.receieveAmount case final receiveAmount?)
                BullDetailsTableItem(
                  label: context.loc.transactionLabelReceiveAmount,
                  displayWidget: BullAmount.signedSats(
                    receiveAmount,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
              if (swapSendNetworkFee != null)
                BullDetailsTableItem(
                  label: context.loc.transactionLabelSendNetworkFees,
                  displayWidget: BullAmount.signedSats(
                    swapSendNetworkFee,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
            ] else if (swap.isLnReceiveSwap) ...[
              if (swap.sendAmount case final sendAmount?)
                BullDetailsTableItem(
                  label: context.loc.transactionLabelSendAmount,
                  displayWidget: BullAmount.signedSats(
                    sendAmount,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
              if (swap.receieveAmount case final receiveAmount?)
                BullDetailsTableItem(
                  label: context.loc.transactionLabelReceiveAmount,
                  displayWidget: BullAmount.signedSats(
                    receiveAmount,
                    interactive: true,
                    overrideHideAmounts: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.onSurface,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ],
          if (swap.fees case final fees? when !recovered)
            BullDetailsTableItem(
              label: swap.type.isChain
                  ? context.loc.transactionDetailLabelTransferFees
                  : context.loc.transactionDetailLabelSwapFees,
              displayWidget: BullAmount.signedSats(
                swap.isLnReceiveSwap
                    ? fees.totalFees(swap.amountSat)
                    : fees.totalFeesMinusLockup(swap.amountSat),
                interactive: true,
                overrideHideAmounts: true,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.onSurface,
                textAlign: TextAlign.end,
              ),
              expandableChild: Column(
                children: [
                  const Gap(4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BullText(
                      swap.isLnReceiveSwap
                          ? context.loc.transactionFeesDeductedFrom
                          : context.loc.transactionFeesTotalDeducted,
                      style: context.bullType.caption,
                      color: context.appColors.secondary,
                    ),
                  ),
                  if (fees.lockupFee case final lockupFee?
                      when swap.isLnReceiveSwap)
                    _feeRow(
                      context,
                      context.loc.transactionDetailLabelSendNetworkFee,
                      lockupFee,
                    ),
                  if (fees.claimFee case final claimFee?)
                    _feeRow(
                      context,
                      context.loc.transactionLabelReceiveNetworkFee,
                      claimFee,
                    ),
                  if (fees.serverNetworkFees case final serverNetworkFees?)
                    _feeRow(
                      context,
                      context.loc.transactionLabelServerNetworkFees,
                      serverNetworkFees,
                    ),
                  _feeRow(
                    context,
                    context.loc.transactionDetailLabelTransferFee,
                    fees.boltzFee ?? 0,
                  ),
                  const Gap(4),
                ],
              ),
            ),
          BullDetailsTableItem(
            label: context.loc.transactionDetailLabelCreatedAt,
            displayValue: dateTime.format(swap.creationTime),
          ),
          if (swap.completionTime != null)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelCompletedAt,
              displayValue: dateTime.format(swap.completionTime!),
            ),
        ],
        if (payjoin != null) ...[
          BullDetailsTableItem(
            label: context.loc.transactionDetailLabelPayjoinStatus,
            // Display status, derived from the broadcast transaction when it
            // is visible (see Transaction.displayPayjoinStatus): a stale
            // session row can't surface a raw "requested"/"proposed" for a
            // payment already on-chain. The exhaustive switch makes a new
            // PayjoinStatus a compile error rather than a leaked enum name.
            displayValue: switch (transaction!.displayPayjoinStatus!) {
              PayjoinStatus.completed =>
                context.loc.transactionDetailLabelPayjoinCompleted,
              PayjoinStatus.aborted =>
                context.loc.transactionDetailLabelPayjoinAborted,
              PayjoinStatus.expired =>
                context.loc.transactionDetailLabelPayjoinExpired,
              PayjoinStatus.started ||
              PayjoinStatus.requested ||
              PayjoinStatus.proposed =>
                context.loc.transactionDetailLabelPayjoinInProgress,
            },
          ),
          BullDetailsTableItem(
            label: context.loc.transactionDetailLabelPayjoinCreationTime,
            displayValue: dateTime.format(payjoin.createdAt),
          ),
          if (transaction.payjoinFeeContributionSat case final feeContribution?)
            BullDetailsTableItem(
              label: context.loc.transactionDetailLabelPayjoinFeeContribution,
              displayWidget: BullAmount.signedSats(
                feeContribution,
                interactive: true,
                overrideHideAmounts: true,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.onSurface,
                textAlign: TextAlign.end,
              ),
              expandableChild: BullText(
                context.loc.transactionPayjoinFeeContributionExplanation,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: context.appColors.secondary),
                maxLines: 5,
              ),
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
        BullText(
          label,
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          color: context.appColors.secondary,
        ),
        const Spacer(),
        BullAmount.signedSats(
          amt,
          interactive: true,
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          color: context.appColors.secondary,
        ),
      ],
    ),
  );
}
