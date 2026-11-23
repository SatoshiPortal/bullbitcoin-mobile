import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/btc_network.dart';
import '../domain/entities/default_wallet.dart';
import '../domain/entities/limit_order.dart';
import '../domain/entities/order.dart';
import '../domain/entities/user_summary.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_orders.dart';
import '../domain/unknown_write_journal.dart';

/// What one reconciliation did: how many open entries it settled and how
/// many are still open (a re-read failed or could not decide).
@immutable
final class UnknownWriteReconciliation {
  final int settled;
  final int open;

  const UnknownWriteReconciliation({required this.settled, required this.open});

  @override
  bool operator ==(Object other) =>
      other is UnknownWriteReconciliation &&
      other.settled == settled &&
      other.open == open;

  @override
  int get hashCode => Object.hash(settled, open);

  @override
  String toString() =>
      'UnknownWriteReconciliation($settled settled, $open open)';
}

/// Settles the open journal entries of an environment by re-reading what
/// each write would have changed. It never sends a write again. An entry
/// stays open when the re-read fails or can't tell.
final class ReconcileUnknownWritesUsecase {
  final UnknownWriteJournal _journal;
  final ExchangeOrders Function(ExchangeEnvironment) _orders;
  final Future<Result<UserSummary, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )
  _getUserSummary;
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function()
  _listOpenLimitOrders;
  final Future<Result<DefaultWallets, ExchangeFailure>> Function()
  _getDefaultWallets;

  const ReconcileUnknownWritesUsecase({
    required UnknownWriteJournal journal,
    required ExchangeOrders Function(ExchangeEnvironment) orders,
    required Future<Result<UserSummary, ExchangeFailure>> Function(
      ExchangeEnvironment,
    )
    getUserSummary,
    required Future<Result<List<LimitOrder>, ExchangeFailure>> Function()
    listOpenLimitOrders,
    required Future<Result<DefaultWallets, ExchangeFailure>> Function()
    getDefaultWallets,
  }) : _journal = journal,
       _orders = orders,
       _getUserSummary = getUserSummary,
       _listOpenLimitOrders = listOpenLimitOrders,
       _getDefaultWallets = getDefaultWallets;

  @useResult
  Future<Result<UnknownWriteReconciliation, UnknownWriteJournalFailure>>
  execute(ExchangeEnvironment environment) async {
    final List<UnknownWrite> entries;
    switch (await _journal.open(environment)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        entries = value;
    }
    var settled = 0;
    var open = 0;
    for (final entry in entries) {
      final settlement = await _settlementOf(entry, environment);
      if (settlement == null) {
        open++;
        continue;
      }
      switch (await _journal.settle(entry.id, settlement)) {
        case Ok():
          settled++;
        case Err():
          open++;
      }
    }
    return Ok(UnknownWriteReconciliation(settled: settled, open: open));
  }

  Future<UnknownWriteSettlement?> _settlementOf(
    UnknownWrite entry,
    ExchangeEnvironment environment,
  ) async {
    switch (entry.kind) {
      case UnknownWriteKind.buyConfirm ||
          UnknownWriteKind.withdrawConfirm ||
          UnknownWriteKind.accelerate:
        final orderId = entry.orderId;
        if (orderId == null) return null;
        return switch (await _orders(environment).getOrder(orderId)) {
          Ok(value: final order) => switch (entry.kind) {
            UnknownWriteKind.accelerate => accelerateSettlement(order),
            UnknownWriteKind.buyConfirm ||
            UnknownWriteKind.withdrawConfirm ||
            UnknownWriteKind.dcaCreate ||
            UnknownWriteKind.limitOrderCreate ||
            UnknownWriteKind.defaultWalletSave => confirmSettlement(order),
          },
          Err() => null,
        };
      case UnknownWriteKind.dcaCreate:
        return switch (await _getUserSummary(environment)) {
          Ok(:final value) => dcaSettlement(entry.request, value.dca),
          Err() => null,
        };
      case UnknownWriteKind.limitOrderCreate:
        return switch (await _listOpenLimitOrders()) {
          Ok(:final value) => limitOrderSettlement(entry.request, value),
          Err() => null,
        };
      case UnknownWriteKind.defaultWalletSave:
        return switch (await _getDefaultWallets()) {
          Ok(:final value) => defaultWalletSettlement(entry.request, value),
          Err() => null,
        };
    }
  }
}

/// A confirm took effect once the order left "awaiting confirmation" for
/// progress; an order still awaiting it was not confirmed; an order that
/// ended no longer needs the confirm. An unknown status can't tell.
UnknownWriteSettlement? confirmSettlement(Order order) =>
    switch (order.orderStatus) {
      OrderStatus.inProgress ||
      OrderStatus.completed => UnknownWriteSettlement.applied,
      OrderStatus.awaitingConfirmation => UnknownWriteSettlement.notApplied,
      OrderStatus.canceled ||
      OrderStatus.expired ||
      OrderStatus.orderExpired ||
      OrderStatus.rejected ||
      OrderStatus.failed => UnknownWriteSettlement.orderEnded,
      OrderStatus.unknown => null,
    };

/// Whether an accelerate took effect can't be read back; it stops mattering
/// once the payout is sent or the order ended. Until then the entry stays
/// open, so a second accelerate is never offered as if the first was lost.
UnknownWriteSettlement? accelerateSettlement(Order order) =>
    order.orderStatus.isTerminal ||
        order.payoutStatus.isTerminal ||
        order.transactionId != null
    ? UnknownWriteSettlement.orderEnded
    : null;

/// The account has one recurring buy: active with the address sent means it
/// was created; inactive, or active with another address, means not.
UnknownWriteSettlement dcaSettlement(
  Map<String, String> request,
  UserDca dca,
) => dca.isActive && dca.address == request['address']
    ? UnknownWriteSettlement.applied
    : UnknownWriteSettlement.notApplied;

/// An open limit order with the same address, currency, price and amount
/// means the create took effect. No match can't tell: the order may already
/// have executed or expired, so the entry stays open.
UnknownWriteSettlement? limitOrderSettlement(
  Map<String, String> request,
  List<LimitOrder> openOrders,
) {
  final price = double.tryParse(request['limitPrice'] ?? '');
  final amount = double.tryParse(request['fiatAmount'] ?? '');
  if (price == null || amount == null) return null;
  final matches = openOrders.any(
    (order) =>
        order.address == request['address'] &&
        order.currencyCode == request['currency'] &&
        (order.limitPrice - price).abs() < 0.005 &&
        (order.fiatAmount - amount).abs() < 0.005,
  );
  return matches ? UnknownWriteSettlement.applied : null;
}

/// The default wallet of the type sent holds the address sent: saved.
/// Anything else: not saved (saving again updates, it can't duplicate).
UnknownWriteSettlement? defaultWalletSettlement(
  Map<String, String> request,
  DefaultWallets wallets,
) {
  BtcNetwork? type;
  for (final network in BtcNetwork.values) {
    if (network.name == request['walletType']) type = network;
  }
  if (type == null) return null;
  final wallet = switch (type) {
    BtcNetwork.bitcoin => wallets.bitcoin,
    BtcNetwork.lightning => wallets.lightning,
    BtcNetwork.liquid => wallets.liquid,
  };
  return wallet != null && wallet.address == request['address']
      ? UnknownWriteSettlement.applied
      : UnknownWriteSettlement.notApplied;
}
