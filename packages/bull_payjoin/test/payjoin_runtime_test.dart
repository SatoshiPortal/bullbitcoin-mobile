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

final class _LabelsPort implements PayjoinLabelsPort {
  @override
  Future<void> labelTransaction({
    required String walletId,
    required String transactionId,
  }) async {}
}

final class _LegacyData implements PayjoinLegacyDataPort {
  final PayjoinLegacyPolicy policy;

  const _LegacyData(this.policy);

  @override
  Future<PayjoinLegacySnapshot> readSnapshot() async => PayjoinLegacySnapshot(
    sourceSchemaVersion: 14,
    senders: const [],
    receivers: const [],
    policy: policy,
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

  Future<Result<PayjoinLifecycle, PayjoinFailure>> open(
    PayjoinLegacyPolicy policy, {
    PayjoinLogPort? log,
  }) {
    return openPayjoin(
      databasePath: '${directory.path}/payjoin.sqlite',
      wallet: _WalletPort(),
      blockchain: _BlockchainPort(),
      transactions: _TransactionPort(),
      labels: _LabelsPort(),
      legacyData: _LegacyData(policy),
      log: log ?? _LogPort(),
    );
  }

  test('opens roles over migrated policy and disposes cleanly', () async {
    final result = await open(
      const PayjoinLegacyPolicy(
        enabled: true,
        minimumAmountSat: 12000,
        sessionLifetimeSeconds: 7200,
      ),
    );
    final lifecycle = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };

    final policy = await lifecycle.payjoin.policy.load();

    expect(policy, isA<Ok<PayjoinPolicy, PayjoinFailure>>());
    expect((policy as Ok<PayjoinPolicy, PayjoinFailure>).value.enabled, isTrue);
    final invalidMinimum = await lifecycle.payjoin.policy.setMinimumAmount(
      Sats.fromInt(500),
    );
    expect(switch (invalidMinimum) {
      Ok() => null,
      Err(:final failure) => failure,
    }, isA<PayjoinInvalidInputFailure>());
    await lifecycle.dispose();
  });

  test('falls back to default policy for invalid legacy policy', () async {
    final log = _LogPort();
    final result = await open(
      const PayjoinLegacyPolicy(
        enabled: true,
        minimumAmountSat: 500,
        sessionLifetimeSeconds: 7200,
      ),
      log: log,
    );

    // An invalid legacy policy must not brick the open: the import
    // quarantines it and falls back to the defaults (disabled, conservative
    // bounds), reporting the substitution as a warning.
    final lifecycle = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    final policy = await lifecycle.payjoin.policy.load();
    final loaded = switch (policy) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    final defaults = PayjoinPolicy.defaults();
    expect(loaded.enabled, defaults.enabled);
    expect(loaded.minimumAmount.value, defaults.minimumAmount.value);
    expect(loaded.sessionLifetime, defaults.sessionLifetime);
    expect(
      log.events.where((e) => e.code == PayjoinLogCode.migrationFailure),
      isNotEmpty,
    );
    await lifecycle.dispose();
  });
}
