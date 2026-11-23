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
import '../recipients/domain/entities/recipient.dart';
import '../recipients/domain/recipient_identity.dart';
import '../recipients/exchange_recipients.dart';

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
  final ExchangeRecipients _recipients;

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
    required ExchangeRecipients recipients,
  }) : _journal = journal,
       _orders = orders,
       _getUserSummary = getUserSummary,
       _listOpenLimitOrders = listOpenLimitOrders,
       _getDefaultWallets = getDefaultWallets,
       _recipients = recipients;

  /// At most this many recipient pages are read for one entry; a longer
  /// list leaves the entry open.
  static const recipientPageLimit = 20;
  static const recipientPageSize = 50;

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
            UnknownWriteKind.defaultWalletSave ||
            UnknownWriteKind.recipientCreate ||
            UnknownWriteKind.preferencesSave => confirmSettlement(order),
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
      case UnknownWriteKind.recipientCreate:
        final recipients = await _allRecipients(environment);
        if (recipients == null) return null;
        return recipientSettlement(entry.request, recipients);
      case UnknownWriteKind.preferencesSave:
        return switch (await _getUserSummary(environment)) {
          Ok(:final value) => preferencesSettlement(entry.request, value),
          Err() => null,
        };
    }
  }

  /// Every fiat recipient of the account, or null when a page can't be read
  /// or the list is longer than [recipientPageLimit] pages.
  Future<List<Recipient>?> _allRecipients(
    ExchangeEnvironment environment,
  ) async {
    final all = <Recipient>[];
    for (var page = 1; page <= recipientPageLimit; page++) {
      switch (await _recipients.listRecipients(
        isTestnet: environment == ExchangeEnvironment.testnet,
        page: page,
        pageSize: recipientPageSize,
      )) {
        case Err():
          return null;
        case Ok(:final value):
          all.addAll(value.recipients);
          if (value.recipients.isEmpty || all.length >= value.totalRecipients) {
            return all;
          }
      }
    }
    return null;
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

/// A recipient with the identity sent (type and account fields) means the
/// create took effect; a complete list without one means it did not, so
/// saving again can't duplicate it.
UnknownWriteSettlement recipientSettlement(
  Map<String, String> request,
  List<Recipient> recipients,
) {
  bool same(Map<String, String> identity) =>
      identity.length == request.length &&
      identity.entries.every((field) => request[field.key] == field.value);
  return recipients.any((r) => same(recipientIdentity(r.details)))
      ? UnknownWriteSettlement.applied
      : UnknownWriteSettlement.notApplied;
}

/// Every field sent holds the value sent: the save took effect. Anything
/// else: it did not (a preference save can be sent again safely).
UnknownWriteSettlement preferencesSettlement(
  Map<String, String> request,
  UserSummary summary,
) {
  final current = {
    'language': summary.language,
    'currency': summary.currency,
    'dcaEnabled': '${summary.dca.isActive}',
    'autoBuyEnabled': '${summary.autoBuy.isActive}',
    'emailNotificationsEnabled': '${summary.emailNotificationsEnabled}',
  };
  return request.entries.every((field) => current[field.key] == field.value)
      ? UnknownWriteSettlement.applied
      : UnknownWriteSettlement.notApplied;
}
