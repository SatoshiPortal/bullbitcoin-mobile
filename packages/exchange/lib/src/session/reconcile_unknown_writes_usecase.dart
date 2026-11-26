import 'package:bull_logger/bull_logger.dart';
import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/btc_network.dart';
import '../domain/entities/default_wallet.dart';
import '../domain/entities/limit_order.dart';
import '../domain/entities/order.dart';
import '../domain/entities/user_summary.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../domain/repositories/orders_repository.dart';
import '../domain/order_create_journal.dart';
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
/// stays open when the re-read fails or can't tell, until it is older than
/// [UnknownWrite.maxAge]: then it is closed as expired and logged.
final class ReconcileUnknownWritesUsecase {
  final UnknownWriteJournal _journal;
  final OrdersRepository Function(ExchangeEnvironment) _orders;
  final Future<Result<UserSummary, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )
  _getUserSummary;
  final Future<Result<List<LimitOrder>, ExchangeFailure>> Function()
  _listRecentLimitOrders;
  final Future<Result<DefaultWallets, ExchangeFailure>> Function()
  _getDefaultWallets;
  final ExchangeRecipients _recipients;

  const ReconcileUnknownWritesUsecase({
    required this._journal,
    required this._orders,
    required this._getUserSummary,

    /// The account's most recent limit orders in every status.
    required this._listRecentLimitOrders,
    required this._getDefaultWallets,
    required this._recipients,
  });

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
      var settlement = await _settlementOf(entry, environment);
      if (settlement == null && entry.isOverAge(clock.now())) {
        settlement = UnknownWriteSettlement.expired;
        log.warning(
          'Closing a ${entry.kind.wire} journal entry no re-read settled '
          'within ${UnknownWrite.maxAge.inHours} h; its outcome stays unknown',
        );
      }
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
            UnknownWriteKind.preferencesSave ||
            UnknownWriteKind.orderCreate ||
            UnknownWriteKind.payin => confirmSettlement(order),
          },
          Err() => null,
        };
      case UnknownWriteKind.dcaCreate:
        return switch (await _getUserSummary(environment)) {
          Ok(:final value) => dcaSettlement(entry.request, value.dca),
          Err() => null,
        };
      case UnknownWriteKind.limitOrderCreate:
        return switch (await _listRecentLimitOrders()) {
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
      case UnknownWriteKind.payin:
        final orderId = entry.orderId;
        if (orderId == null) return null;
        return switch (await _orders(environment).getOrder(orderId)) {
          Ok(value: final order) => payinSettlement(order),
          Err() => null,
        };
      case UnknownWriteKind.orderCreate:
        final sent = OrderCreateJournalRequest.fromRequest(entry.request);
        if (sent == null) return null;
        return switch (await _orders(environment).getOrders(type: sent.type)) {
          Ok(:final value) => orderCreateSettlement(entry, value),
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

/// A payin took effect once the exchange saw one: any payin status past
/// awaiting payment, a refused payin included (the bitcoin went out). An
/// order that ended without seeing it no longer takes it. Otherwise the
/// transaction may still be on its way, so the entry stays open and no
/// second payin is offered.
UnknownWriteSettlement? payinSettlement(Order order) =>
    switch (order.payinStatus) {
      OrderPayinStatus.inProgress ||
      OrderPayinStatus.underReview ||
      OrderPayinStatus.awaitingConfirmation ||
      OrderPayinStatus.completed ||
      OrderPayinStatus.rejected => UnknownWriteSettlement.applied,
      OrderPayinStatus.notStarted ||
      OrderPayinStatus.awaitingPayment ||
      OrderPayinStatus.unknown =>
        order.orderStatus.isTerminal ? UnknownWriteSettlement.orderEnded : null,
    };

/// Whether an accelerate took effect can't be read back. It is finished once
/// the payout went out (a txid or a completed payout: applied), and stops
/// mattering once the order or the payout ended without that (orderEnded).
/// Until then the entry stays open, so a second accelerate is never offered
/// as if the first was lost.
UnknownWriteSettlement? accelerateSettlement(Order order) {
  if (order.transactionId != null ||
      order.payoutStatus == OrderPayoutStatus.completed) {
    return UnknownWriteSettlement.applied;
  }
  if (order.orderStatus.isTerminal || order.payoutStatus.isTerminal) {
    return UnknownWriteSettlement.orderEnded;
  }
  return null;
}

/// How long before its journal entry was recorded a created order may be
/// dated: the create may have waited out its timeouts before it was
/// journaled.
const orderCreateWindow = Duration(minutes: 10);

/// An order of the type sent, created within [orderCreateWindow] before the
/// entry was recorded (or up to a minute after, for clock skew), with the
/// amount sent, means the create took effect. No match can't tell: the read
/// may not hold the order, or skipped it as malformed. The entry then stays
/// open until [UnknownWrite.maxAge]; an order create never holds the write
/// gate meanwhile.
UnknownWriteSettlement? orderCreateSettlement(
  UnknownWrite entry,
  List<Order> orders,
) {
  final sent = OrderCreateJournalRequest.fromRequest(entry.request);
  if (sent == null) return null;
  return findCreatedOrder(sent, entry.recordedAt, orders) == null
      ? null
      : UnknownWriteSettlement.applied;
}

/// The order a create of [sent] at [sentAt] made, among [orders]: the same
/// rule reconcile settles a journaled create by, for a flow re-reading its
/// own create after an unknown outcome. Null can't tell absence from a read
/// that doesn't hold it; the caller keeps the create unverified, never sends
/// it again.
Order? findCreatedOrder(
  OrderCreateJournalRequest sent,
  DateTime sentAt,
  List<Order> orders,
) {
  final from = sentAt.subtract(orderCreateWindow);
  final until = sentAt.add(const Duration(minutes: 1));
  for (final order in orders) {
    if (order.orderType == sent.type &&
        !order.createdAt.isBefore(from) &&
        !order.createdAt.isAfter(until) &&
        _orderAmountMatches(order, sent)) {
      return order;
    }
  }
  return null;
}

/// A fiat amount matches the side counted in the currency sent (either side
/// when none was sent) to the cent; a bitcoin amount either side to the sat.
bool _orderAmountMatches(Order order, OrderCreateJournalRequest sent) {
  switch (sent.amount) {
    case FiatAmount(:final amount):
      final currency = sent.currency?.code;
      return [
        if (currency == null || order.payinCurrency == currency)
          order.payinAmount,
        if (currency == null || order.payoutCurrency == currency)
          order.payoutAmount,
      ].any((value) => (value - amount).abs() < 0.005);
    case BitcoinAmount(:final amount):
      return [
        order.payinAmount,
        order.payoutAmount,
      ].any((value) => (value - amount).abs() < 0.000000005);
  }
}

/// The account has one recurring buy: active with the address sent means it
/// was created; inactive, or active with another address, means not.
UnknownWriteSettlement dcaSettlement(
  Map<String, String> request,
  UserDca dca,
) => dca.isActive && dca.address == request['address']
    ? UnknownWriteSettlement.applied
    : UnknownWriteSettlement.notApplied;

/// A limit order in any status (active, executed, expired, cancelled,
/// failed) with the same address, currency, price and amount means the
/// create took effect. [orders] is the most recent page; no match there can't
/// tell, so the entry stays open (until [UnknownWrite.maxAge]).
UnknownWriteSettlement? limitOrderSettlement(
  Map<String, String> request,
  List<LimitOrder> orders,
) => findCreatedLimitOrder(request, orders) == null
    ? null
    : UnknownWriteSettlement.applied;

/// The limit order a create of [request] (`LimitOrderDraft.journalRequest`)
/// made, in any status, if [orders] holds it. Reconcile and a flow's own
/// re-read after an unknown outcome use this one match.
LimitOrder? findCreatedLimitOrder(
  Map<String, String> request,
  List<LimitOrder> orders,
) {
  final price = double.tryParse(request['limitPrice'] ?? '');
  final amount = double.tryParse(request['fiatAmount'] ?? '');
  if (price == null || amount == null) return null;
  for (final order in orders) {
    if (order.address == request['address'] &&
        order.currencyCode == request['currency'] &&
        (order.limitPrice - price).abs() < 0.005 &&
        (order.fiatAmount - amount).abs() < 0.005) {
      return order;
    }
  }
  return null;
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
