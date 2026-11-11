import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

base class _WalletPort implements PayjoinWalletPort {
  @override
  Future<bool Function(Uint8List script)> createOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  }) async =>
      (Uint8List _) => false;

  @override
  Future<bool Function(Outpoint outpoint)> createOutpointOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  }) async =>
      (Outpoint _) => false;

  @override
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async => psbt;

  @override
  Future<List<PayjoinUtxo>> spendableUtxos({
    required String walletId,
    required BitcoinNetwork network,
  }) async => const [];
}

final class _BlockchainPort implements PayjoinBlockchainPort {
  @override
  Future<void> broadcastPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {}

  @override
  Future<void> broadcastTransaction({
    required BitcoinNetwork network,
    required Uint8List transaction,
  }) async {}
}

final class _TransactionPort implements PayjoinTransactionPort {
  final bool offline;

  _TransactionPort({this.offline = false});

  @override
  Future<bool> protectObservedSpend({
    required String walletId,
    required String transactionId,
  }) async => true;

  @override
  Future<bool> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  }) async => offline ? throw StateError('offline') : false;

  @override
  Future<void> refreshWallet(String walletId) async {}

  @override
  Stream<void> watchWallet(String walletId) => const Stream.empty();
}

final class _FeesPort implements PayjoinFeesPort {
  @override
  Future<FeeRate> fastestFeeRate({required BitcoinNetwork network}) async =>
      FeeRate(10);
}

final class _LabelsPort implements PayjoinLabelsPort {
  @override
  Future<void> labelTransaction({
    required String walletId,
    required String transactionId,
  }) async {}
}

final class _LegacyData implements PayjoinLegacyDataPort {
  const _LegacyData();

  @override
  Future<PayjoinLegacySnapshot> readSnapshot() async =>
      const PayjoinLegacySnapshot(
        sourceSchemaVersion: 14,
        senders: [],
        receivers: [],
      );
}

final class _BusyWalletPort extends _WalletPort {
  @override
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async => throw const PayjoinSpendBlockedException(busy: true);
}

final class _LogPort implements PayjoinLogPort {
  final List<PayjoinLogEvent> events = [];

  @override
  void write(PayjoinLogEvent event) => events.add(event);
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('payjoin-runtime-');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<Result<PayjoinLifecycle, PayjoinFailure>> open({
    PayjoinLogPort? log,
    bool offline = false,
    PayjoinWalletPort? wallet,
  }) {
    return openPayjoin(
      databasePath: '${directory.path}/payjoin.sqlite',
      wallet: wallet ?? _WalletPort(),
      blockchain: _BlockchainPort(),
      fees: _FeesPort(),
      transactions: _TransactionPort(offline: offline),
      labels: _LabelsPort(),
      legacyData: const _LegacyData(),
      log: log ?? _LogPort(),
    );
  }

  test('a sender refused by a busy wallet says so', () async {
    final lifecycle = switch (await open(wallet: _BusyWalletPort())) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    addTearDown(lifecycle.dispose);

    final result = await lifecycle.payjoin.sender.start(
      StartPayjoinSender(
        walletId: 'wallet-1',
        network: BitcoinNetwork.testnet,
        bip21Uri: 'bitcoin:tb1qnopayjoinendpoint?amount=0.001',
        unsignedOriginalPsbt: 'cHNidP8=',
        amount: Sats.fromInt(100000),
        feeRate: FeeRate(2),
      ),
    );

    expect(
      result,
      isA<Err<PayjoinSenderSession, PayjoinFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PayjoinSpendBlockedFailure>().having((f) => f.busy, 'busy', isTrue),
      ),
    );
  });

  test('a sender that cannot start says why in the log', () async {
    final log = _LogPort();
    final lifecycle = switch (await open(log: log)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    addTearDown(lifecycle.dispose);

    final result = await lifecycle.payjoin.sender.start(
      StartPayjoinSender(
        walletId: 'wallet-1',
        network: BitcoinNetwork.testnet,
        bip21Uri: 'bitcoin:tb1qnopayjoinendpoint?amount=0.001',
        unsignedOriginalPsbt: 'cHNidP8=',
        amount: Sats.fromInt(100000),
        feeRate: FeeRate(2),
      ),
    );

    expect(result, isA<Err<PayjoinSenderSession, PayjoinFailure>>());
    final event = log.events.singleWhere(
      (event) => event.code == PayjoinLogCode.sessionStartFailed,
    );
    expect(event.level, PayjoinLogLevel.warning);
    expect(event.role, PayjoinLogRole.sender);
    expect(event.error, isNotNull);
  });

  test(
    'recovered paused proposal is typed in both session reads and events',
    () async {
      final initial = switch (await open()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      await initial.dispose();
      final database = PayjoinDatabase.open('${directory.path}/payjoin.sqlite');
      final model = PayjoinSenderModel(
        uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
        isTestnet: true,
        sender: '[]',
        walletId: 'wallet-1',
        originalPsbt: 'cHNidP8=',
        originalTxId: 'original-tx',
        amountSat: 50000,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7200,
        expireAfterSec: 3600,
        proposalPsbt: 'cHNidP8=',
        txId: 'proposal-tx',
      );
      await LocalPayjoinDatasource(db: database).storeSender(model);
      await database.close();
      // Unknown visibility keeps an expired proposal paused, not released.
      final lifecycle = switch (await open(offline: true)) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      addTearDown(lifecycle.dispose);
      final event = lifecycle.payjoin.sessions
          .watch(sessionIds: {model.id})
          .first;
      expect(await lifecycle.resume(), isA<Ok<void, PayjoinFailure>>());
      final update = switch (await event) {
        Ok(:final value) => value as PayjoinSenderSession,
        Err(:final failure) => throw failure,
      };
      expect(update.spendFailure, isA<PayjoinSpendBlockedFailure>());
      expect(update.isOngoing, isTrue);
      expect(update.canRetryProposal, isFalse);
      final read = switch (await lifecycle.payjoin.sessions.byId(model.id)) {
        Ok(:final value) => value as PayjoinSenderSession,
        Err(:final failure) => throw failure,
      };
      expect(read.spendFailure, isA<PayjoinSpendBlockedFailure>());
      expect(
        await lifecycle.payjoin.sender.retryProposal(model.id),
        isA<Err<PayjoinSession, PayjoinFailure>>(),
      );
    },
  );

  test('opens roles over the seeded policy and disposes cleanly', () async {
    final result = await open();
    final lifecycle = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

    final policy = await lifecycle.payjoin.policy.load();

    // Nothing to migrate: the root settings payjoin columns only existed in
    // the unreleased schema 14, so a freshly opened payjoin database starts on
    // the defaults, receiving from users disabled.
    final loaded = switch (policy) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    final defaults = PayjoinPolicy.defaults();
    expect(loaded.receiveEnabled, defaults.receiveEnabled);
    expect(loaded.receiveEnabled, isFalse);
    expect(loaded.sendEnabled, isTrue);
    expect(loaded.buyEnabled, isTrue);
    expect(loaded.sellEnabled, isTrue);
    expect(loaded.minimumAmount.value, defaults.minimumAmount.value);
    expect(loaded.sessionLifetime, defaults.sessionLifetime);

    final invalidMinimum = await lifecycle.payjoin.policy.setMinimumAmount(
      Sats.fromInt(500),
    );
    expect(switch (invalidMinimum) {
      Ok() => null,
      Err(:final failure) => failure,
    }, isA<PayjoinInvalidInputFailure>());
    await lifecycle.dispose();
  });
}
