import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
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
      databaseKey: 'test-only-payjoin-key',
      wallet: _WalletPort(),
      blockchain: _BlockchainPort(),
      fees: _FeesPort(),
      transactions: _TransactionPort(),
      labels: _LabelsPort(),
      legacyData: const _LegacyData(),
      log: log ?? _LogPort(),
    );
  }

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
    expect(loaded.enabled, defaults.enabled);
    expect(loaded.enabled, isFalse);
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
