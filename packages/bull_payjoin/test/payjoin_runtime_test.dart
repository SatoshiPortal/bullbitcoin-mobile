import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/engine/bitcoin_tx.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _WalletPort implements PayjoinWalletPort {
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
  Future<String Function(String psbt)> createPsbtProcessor({
    required String walletId,
    required BitcoinNetwork network,
  }) async =>
      (String psbt) => psbt;

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
  @override
  Future<bool> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  }) async => false;

  @override
  Future<String?> findTransactionSpending({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async => null;

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

  Future<Result<PayjoinLifecycle, PayjoinFailure>> open({PayjoinLogPort? log}) {
    return openPayjoin(
      databasePath: '${directory.path}/payjoin.sqlite',
      wallet: _WalletPort(),
      blockchain: _BlockchainPort(),
      fees: _FeesPort(),
      transactions: _TransactionPort(),
      labels: _LabelsPort(),
      legacyData: const _LegacyData(),
      log: log ?? _LogPort(),
    );
  }

  group('ownership of a receiver whose payjoin landed under another txid', () {
    // The sender's input 11..:0 pays 50 000 sat to the receiver's address;
    //  the proposal adds the receiver's input 44..:1.
    const paymentAddress = 'tb1qyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zjuhu9x';
    const originalHex =
        '0200000001111111111111111111111111111111111111111111111111111111111111'
        '11110000000000fdffffff0150c30000000000001600142222222222222222222222'
        '22222222222222222200000000';
    const proposalPsbt =
        'cHNidP8BAHsCAAAAAhERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
        'REREREREREREREREREREREREREREREREREREREREREQBAAAAAP3///8B8EkCAAAAAAAWABQi'
        'IiIiIiIiIiIiIiIiIiIiIiIiIgAAAAAAAQEfaIcBAAAAAAAWABQzMzMzMzMzMzMzMzMzMzMz'
        'MzMzMwABAR8YxAAAAAAAABYAFFVVVVVVVVVVVVVVVVVVVVVVVVVVAAA=';
    const sessionId = '0123456789abcdef';
    final landedTxId = '77' * 32;

    Future<PayjoinSession?> stored({required bool isCompleted}) async {
      final originalBytes = Uint8List.fromList([
        for (var i = 0; i < originalHex.length; i += 2)
          int.parse(originalHex.substring(i, i + 2), radix: 16),
      ]);
      // Created and migrated by the runtime itself first.
      await switch (await open()) {
        Ok(:final value) => value.dispose(),
        Err(:final failure) => throw failure,
      };
      final database = PayjoinDatabase.open('${directory.path}/payjoin.sqlite');
      await LocalPayjoinDatasource(db: database).storeReceiver(
        (PayjoinModel.receiver(
                  id: sessionId,
                  address: paymentAddress,
                  isTestnet: true,
                  receiver: '[]',
                  walletId: 'wallet-1',
                  pjUri:
                      'bitcoin:$paymentAddress?amount=0.0005'
                      '&pj=https://payjo.in/$sessionId',
                  maxFeeRateSatPerVb: BigInt.from(10000),
                  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  expireAfterSec: 3600,
                  originalTxBytes: originalBytes,
                  originalTxId: BitcoinTx.fromBytesSync(originalBytes).txid,
                  amountSat: 50000,
                  proposalPsbt: proposalPsbt,
                  txId: landedTxId,
                )
                as PayjoinReceiverModel)
            .copyWith(isCompleted: isCompleted),
      );
      await database.close();

      final lifecycle = switch (await open()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      addTearDown(lifecycle.dispose);
      return switch (await lifecycle.payjoin.sessions.byId(sessionId)) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    }

    test('a completed one keeps its breakdown', () async {
      final session = await stored(isCompleted: true);

      expect(session?.transactionId, landedTxId);
      expect(session?.ownership?.inputs, [
        PayjoinParty.sender,
        PayjoinParty.recipient,
      ]);
      expect(session?.ownership?.outputs, [PayjoinParty.recipient]);
    });

    test('an unfinished one has none', () async {
      final session = await stored(isCompleted: false);

      expect(session, isNotNull);
      expect(session?.ownership, isNull);
    });
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

  test('opens roles over the seeded policy and disposes cleanly', () async {
    final result = await open();
    final lifecycle = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

    final policy = await lifecycle.payjoin.policy.load();

    // Nothing to migrate: the root settings payjoin columns only existed in
    // the unreleased schema 14, so a freshly opened payjoin database starts on
    // the conservative defaults, payjoin disabled.
    final loaded = switch (policy) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    final defaults = PayjoinPolicy.defaults();
    expect(loaded.receiveEnabled, defaults.receiveEnabled);
    expect(loaded.receiveEnabled, isFalse);
    expect(loaded.sendEnabled, isFalse);
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
