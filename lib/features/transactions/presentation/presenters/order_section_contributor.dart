import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/models/transaction_detail_view.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_section_contributor.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/tx_format.dart';

/// Exchange orders (buy, sell, fiat payment, funding, withdraw, reward, refund,
/// balance adjustment). Owns the full presentation for an order transaction.
class OrderSectionContributor extends TransactionSectionContributor {
  const OrderSectionContributor();

  @override
  int get priority => 10;

  @override
  bool appliesTo(Transaction tx) => tx.isOrder;

  @override
  TxHeaderView? header(Transaction tx, TxPresentDeps deps) {
    final order = tx.order!;
    final orderAmountAndCurrency = order.amountAndCurrencyToDisplay();
    final showOrderInFiat =
        order is FiatPaymentOrder ||
        order is BalanceAdjustmentOrder ||
        order is WithdrawOrder ||
        order is FundingOrder;

    return TxHeaderView(
      isIncoming: tx.isIncoming,
      isTransfer: false,
      statusLabel: order.orderType.value,
      amount: showOrderInFiat
          ? TxAmountView(
              fiatAmount: orderAmountAndCurrency.$1.toDouble(),
              fiatCurrency: orderAmountAndCurrency.$2,
            )
          : TxAmountView(sats: orderAmountAndCurrency.$1.toInt()),
    );
  }

  @override
  List<TxDetailRow> rows(Transaction tx, TxPresentDeps deps) {
    final order = tx.order!;
    final loc = deps.loc;

    TxDetailRow statusRow() => TxDetailRow(
      label: loc.transactionDetailLabelOrderStatus,
      value: TxText(order.orderStatus.value),
      expandedRows: [
        TxDetailRow(
          label: loc.transactionDetailLabelPayinStatus,
          value: TxText(order.payinStatus.value),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelOrderStatus,
          value: TxText(order.orderStatus.value),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutStatus,
          value: TxText(order.payoutStatus.value),
        ),
      ],
    );

    TxDetailRow orderTypeRow() => TxDetailRow(
      label: loc.transactionDetailLabelOrderType,
      value: TxText(order.orderType.value),
    );

    TxDetailRow orderNumberRow() => TxDetailRow(
      label: loc.transactionDetailLabelOrderNumber,
      value: TxText(order.orderNumber.toString()),
      copyValue: order.orderNumber.toString(),
    );

    TxDetailRow exchangeRateRow(Object? amount, Object? currency) =>
        TxDetailRow(
          label: loc.transactionDetailLabelExchangeRate,
          value: TxText('$amount $currency'),
        );

    TxDetailRow payinMethodRow() => TxDetailRow(
      label: loc.transactionDetailLabelPayinMethod,
      value: TxText(order.payinMethod.value),
    );

    TxDetailRow payoutMethodRow() => TxDetailRow(
      label: loc.transactionDetailLabelPayoutMethod,
      value: TxText(order.payoutMethod.value),
    );

    TxDetailRow createdAtRow() => TxDetailRow(
      label: loc.transactionDetailLabelCreatedAt,
      value: TxText(formatTxDate(order.createdAt)),
    );

    if (order is BuyOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: order.payinCurrency == 'LBTC' || order.payinCurrency == 'BTC'
              ? TxAmount(ConvertAmount.btcToSats(order.payinAmount))
              : TxText(
                  '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: order.payoutCurrency == 'LBTC' || order.payoutCurrency == 'BTC'
              ? TxAmount(ConvertAmount.btcToSats(order.payoutAmount))
              : TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is SellOrder) {
      final payinAmountSat = ConvertAmount.btcToSats(order.payinAmount);
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: TxAmount(payinAmountSat),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is FiatPaymentOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        if (order.paymentDescription != null &&
            order.paymentDescription!.isNotEmpty)
          TxDetailRow(
            label: loc.transactionDetailLabelPaymentDescription,
            value: TxText(order.paymentDescription!),
          ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        if (order.referenceNumber != null)
          TxDetailRow(
            label: loc.transactionOrderLabelReferenceNumber,
            value: TxText(order.referenceNumber!),
            copyValue: order.referenceNumber,
          ),
        if (order.originName != null)
          TxDetailRow(
            label: loc.transactionOrderLabelOriginName,
            value: TxText(order.originName!),
          ),
        if (order.originCedula != null)
          TxDetailRow(
            label: loc.transactionOrderLabelOriginCedula,
            value: TxText(order.originCedula!),
          ),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is FundingOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: TxText(
            '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
          ),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is WithdrawOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: TxText(
            '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
          ),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is RewardOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: order.payinCurrency == 'LBTC' || order.payinCurrency == 'BTC'
              ? TxAmount(ConvertAmount.btcToSats(order.payinAmount))
              : TxText(
                  '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: order.payoutCurrency == 'LBTC' || order.payoutCurrency == 'BTC'
              ? TxAmount(ConvertAmount.btcToSats(order.payoutAmount))
              : TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is RefundOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: order.payinCurrency == 'LBTC' || order.payinCurrency == 'BTC'
              ? TxAmount(ConvertAmount.btcToSats(order.payinAmount))
              : TxText(
                  '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
                ),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: order.payoutCurrency == 'LBTC' || order.payoutCurrency == 'BTC'
              ? TxAmount(ConvertAmount.btcToSats(order.payoutAmount))
              : TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    } else if (order is BalanceAdjustmentOrder) {
      return [
        orderTypeRow(),
        orderNumberRow(),
        TxDetailRow(
          label: loc.transactionDetailLabelPayinAmount,
          value: TxText(
            '${order.payinAmount.toStringAsFixed(2)} ${order.payinCurrency}',
          ),
        ),
        TxDetailRow(
          label: loc.transactionDetailLabelPayoutAmount,
          value: TxText('${order.payoutAmount} ${order.payoutCurrency}'),
        ),
        if (order.exchangeRateAmount != null &&
            order.exchangeRateCurrency != null)
          exchangeRateRow(order.exchangeRateAmount, order.exchangeRateCurrency),
        payinMethodRow(),
        payoutMethodRow(),
        statusRow(),
        createdAtRow(),
        if (order.completedAt != null)
          TxDetailRow(
            label: loc.transactionDetailLabelCompletedAt,
            value: TxText(formatTxDate(order.completedAt!)),
          ),
      ];
    }

    return [orderTypeRow()];
  }
}
