import 'package:exchange/exchange.dart'
    show ExchangeFailure, ExchangeNotAuthenticatedFailure;
import 'package:transactions/src/domain/entities/transaction.dart';

/// The merged history: wallet activity plus what is known about the user's
/// exchange orders. A failed order read is [ExchangeOrdersUnavailable], never
/// an empty order list.
final class TransactionHistory {
  const TransactionHistory({
    required this.transactions,
    required this.exchangeOrders,
  });

  final List<Transaction> transactions;
  final ExchangeOrdersInHistory exchangeOrders;
}

sealed class ExchangeOrdersInHistory {
  const ExchangeOrdersInHistory();

  /// The order read's failure, mapped to what the history shows.
  factory ExchangeOrdersInHistory.ofFailure(ExchangeFailure failure) =>
      switch (failure) {
        ExchangeNotAuthenticatedFailure() => const ExchangeOrdersNoAccount(),
        ExchangeFailure() => ExchangeOrdersUnavailable(failure),
      };
}

/// The orders were read and merged into the list.
final class ExchangeOrdersMerged extends ExchangeOrdersInHistory {
  const ExchangeOrdersMerged();
}

/// No exchange account is stored on this device: there are no orders to read.
final class ExchangeOrdersNoAccount extends ExchangeOrdersInHistory {
  const ExchangeOrdersNoAccount();
}

/// The wallet network has no exchange (regtest).
final class ExchangeOrdersNotOffered extends ExchangeOrdersInHistory {
  const ExchangeOrdersNotOffered();
}

/// The order read failed: the list holds wallet activity only.
final class ExchangeOrdersUnavailable extends ExchangeOrdersInHistory {
  const ExchangeOrdersUnavailable(this.failure);

  final ExchangeFailure failure;
}
