import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

/// The buy order calls of one test: each answers what it was given and
/// throws when the test gave none; every call is logged.
final class BuyTestOrders extends Fake implements ExchangeOrders {
  ExchangeWrite<BuyOrder>? placed;
  Result<List<Order>, ExchangeFailure>? listed;
  Result<BuyOrder, ExchangeFailure>? refreshed;
  ExchangeWrite<BuyOrder>? confirmed;
  Result<Order, ExchangeFailure>? read;
  ExchangeWrite<BuyOrder>? accelerated;
  final log = <String>[];

  T _given<T>(T? answer, String call) =>
      answer ?? (throw StateError('unexpected $call'));

  @override
  Future<ExchangeWrite<BuyOrder>> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  }) async {
    log.add(
      'place $toAddress ${currency.code} ${network.name} owner=$isOwner '
      'bip21=$payjoinBip21',
    );
    return _given(placed, 'place');
  }

  @override
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    log.add('list ${type?.name}');
    return _given(listed, 'list');
  }

  @override
  Future<Result<BuyOrder, ExchangeFailure>> refreshBuyOrder(
    String orderId,
  ) async {
    log.add('refresh $orderId');
    return _given(refreshed, 'refresh');
  }

  @override
  Future<ExchangeWrite<BuyOrder>> confirmBuyOrder(String orderId) async {
    log.add('confirm $orderId');
    return _given(confirmed, 'confirm');
  }

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) async {
    log.add('read $orderId');
    return _given(read, 'read');
  }

  @override
  Future<ExchangeWrite<BuyOrder>> accelerateBuyOrder(String orderId) async {
    log.add('accelerate $orderId');
    return _given(accelerated, 'accelerate');
  }
}

/// A payjoin receiver that opens [opened] (or fails) and logs each call.
final class BuyTestReceiver extends Fake implements PayjoinReceiver {
  final Result<PayjoinReceiverSession, PayjoinFailure> opened;
  final log = <String>[];
  final started = <StartPayjoinReceiver>[];

  BuyTestReceiver([this.opened = const Err(PayjoinUnavailableFailure())]);

  @override
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  ) async {
    started.add(request);
    log.add('start ${request.walletId}');
    return opened;
  }

  @override
  Future<Result<void, PayjoinFailure>> cancel(String sessionId) async {
    log.add('cancel $sessionId');
    return const Ok(null);
  }
}

/// The ongoing payjoin sessions [ongoing].
final class BuyTestPayjoinSessions extends Fake implements PayjoinSessions {
  final List<PayjoinSession> ongoing;
  var lists = 0;

  BuyTestPayjoinSessions(this.ongoing);

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  ) async {
    lists++;
    return Ok(ongoing);
  }
}

PayjoinReceiverSession buyReceiverSession({
  String id = 'pj-1',
  String uri = 'bitcoin:bc1qreceive?pj=https://relay.example/abc',
}) => PayjoinReceiverSession(
  status: PayjoinStatus.requested,
  id: id,
  network: BitcoinNetwork.mainnet,
  walletId: 'w-btc',
  createdAt: DateTime.utc(2026, 11, 24, 10),
  expiresAt: DateTime.utc(2026, 11, 24, 11),
  payjoinUri: uri,
);

/// The payjoin policy [buyEnabled] (null: unreadable).
final class BuyTestPolicy extends Fake implements PayjoinPolicyAccess {
  final bool? buyEnabled;

  BuyTestPolicy({this.buyEnabled});

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async =>
      switch (buyEnabled) {
        final enabled? => Ok(
          PayjoinPolicy(
            sendEnabled: true,
            receiveEnabled: true,
            buyEnabled: enabled,
            sellEnabled: true,
            minimumAmount: PayjoinPolicy.minimumAllowedAmount,
            sessionLifetime: const Duration(hours: 1),
          ),
        ),
        null => const Err(PayjoinUnavailableFailure()),
      };
}

/// The wallets per network (a network missing from [wallets] fails). A
/// re-read of one wallet finds it gone (so no native receive runs in a
/// test); [reads] records it.
final class BuyTestInventory extends Fake implements WalletInventory {
  final Map<Network, List<WalletRegistration>> wallets;
  final asked = <Network>[];
  final reads = <String>[];

  BuyTestInventory(this.wallets);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async {
    asked.add(network);
    return switch (wallets[network]) {
      final listed? => Ok(walletSelectionForTesting(listed)),
      null => const Err(WalletRegistrationNotFoundFailure()),
    };
  }

  @override
  Future<Result<WalletRegistration, SecretFailure>> readWallet(
    String id,
  ) async {
    reads.add(id);
    return const Err(WalletRegistrationNotFoundFailure());
  }
}

/// The native wallet runtime: no call is expected.
final class BuyTestNative extends Fake implements WalletNativeLifecycle {}
