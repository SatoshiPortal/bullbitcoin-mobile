import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum TransactionsRoute {
  transactions('/transactions'),
  exchangeTransactions('/transactions/exchange'),
  exportTransactions('/transactions/export'),
  transactionDetails('/transaction/:txId'),
  swapTransactionDetails('/transaction/swap/:swapId'),
  payjoinTransactionDetails('/transaction/payjoin/:payjoinId'),
  payjoinTransactionDetailsByTxId('/transaction/payjoin/tx/:txId'),
  orderSwapTransactionDetails('/transaction/order-swap/:localId'),
  orderTransactionDetails('/transaction/order/:orderId');

  const TransactionsRoute(this.path);

  final String path;
}

/// The view the transaction details open on. [status] is the payment status
/// (shown only when the transaction has one); [details] the transaction
/// details. Carried as the `view=details` query parameter, absent for status.
enum TransactionDetailsView {
  status,
  details;

  static const queryParameter = 'view';

  /// The view named by the `view` query parameter, [status] when absent.
  static TransactionDetailsView fromQuery(Map<String, String> query) =>
      query[queryParameter] == details.name ? details : status;
}

final class TransactionDetailsTarget {
  final TransactionsRoute _route;
  final String _parameter;
  final String _id;
  final String? _walletId;

  const TransactionDetailsTarget.wallet(String txId, {required String walletId})
    : this._(TransactionsRoute.transactionDetails, 'txId', txId, walletId);

  const TransactionDetailsTarget.swap(String swapId, {required String walletId})
    : this._(
        TransactionsRoute.swapTransactionDetails,
        'swapId',
        swapId,
        walletId,
      );

  const TransactionDetailsTarget.payjoin(String payjoinId)
    : this._(
        TransactionsRoute.payjoinTransactionDetails,
        'payjoinId',
        payjoinId,
      );

  const TransactionDetailsTarget.payjoinByTxId(String txId)
    : this._(TransactionsRoute.payjoinTransactionDetailsByTxId, 'txId', txId);

  const TransactionDetailsTarget.orderSwap(String localId)
    : this._(TransactionsRoute.orderSwapTransactionDetails, 'localId', localId);

  const TransactionDetailsTarget.order(String orderId)
    : this._(TransactionsRoute.orderTransactionDetails, 'orderId', orderId);

  const TransactionDetailsTarget._(
    this._route,
    this._parameter,
    this._id, [
    this._walletId,
  ]);

  Map<String, String> _query({
    required bool returnHome,
    required bool returnToExchange,
    required TransactionDetailsView view,
  }) => {
    'walletId': ?_walletId,
    if (view == TransactionDetailsView.details)
      TransactionDetailsView.queryParameter: view.name,
    if (returnHome) 'returnHome': 'true',
    if (returnToExchange) 'returnToExchange': 'true',
  };
}

abstract final class TransactionsNavigation {
  static Future<void> openHistory(
    BuildContext context, {
    bool exchangeOnly = false,
  }) => context.pushNamed<void>(
    (exchangeOnly
            ? TransactionsRoute.exchangeTransactions
            : TransactionsRoute.transactions)
        .name,
  );

  static Future<void> openExport(BuildContext context) =>
      context.pushNamed<void>(TransactionsRoute.exportTransactions.name);

  static Future<void> openDetails(
    BuildContext context,
    TransactionDetailsTarget target, {
    bool returnHome = false,
    bool returnToExchange = false,
    TransactionDetailsView view = TransactionDetailsView.status,
  }) => context.pushNamed<void>(
    target._route.name,
    pathParameters: {target._parameter: target._id},
    queryParameters: target._query(
      returnHome: returnHome,
      returnToExchange: returnToExchange,
      view: view,
    ),
  );

  static void goToDetails(
    BuildContext context,
    TransactionDetailsTarget target, {
    bool returnHome = false,
    bool returnToExchange = false,
    TransactionDetailsView view = TransactionDetailsView.status,
  }) => context.goNamed(
    target._route.name,
    pathParameters: {target._parameter: target._id},
    queryParameters: target._query(
      returnHome: returnHome,
      returnToExchange: returnToExchange,
      view: view,
    ),
  );
}
