import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'support/test_codec.dart';
import 'support/regtest_transport_fixture.dart';

base class _WalletPort implements PayjoinWalletPort {
  @override
  Future<PayjoinWalletOwnership> captureOwnership({
    required String walletId,
    required BitcoinNetwork network,
  }) async => PayjoinWalletOwnership(
    ownsScript: (_) => false,
    ownsOutpoint: (_) => false,
  );

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
    required String sessionId,
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

final class _CountingLegacy implements PayjoinLegacyDataPort {
  int reads = 0;
  @override
  Future<PayjoinLegacySnapshot> readSnapshot() async {
    reads++;
    return const PayjoinLegacySnapshot(
      sourceSchemaVersion: 14,
      senders: [],
      receivers: [],
    );
  }
}

void main() {
  late Directory directory;
  late RegtestTlsFixture fixture;
  setUpAll(() async {
    fixture = await RegtestTlsFixture.create();
  });
  tearDownAll(() => fixture.dispose());

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('payjoin-runtime-');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<Result<PayjoinLifecycle, PayjoinFailure>> open({
    PayjoinLogPort? log,
    bool offline = false,
    PayjoinWalletPort? wallet,
    PayjoinRegtestProfile? profile,
    RegtestHostProfile? host,
    PayjoinLegacyDataPort? legacy,
    Future<bool> Function()? isCurrent,
  }) {
    return openPayjoinForTesting(
      regtestProfile: profile,
      regtestHostProfile: host,
      isCurrent: isCurrent,
      codec: const TestPayjoinCodec(),
      databasePath: '${directory.path}/payjoin.sqlite',
      wallet: wallet ?? _WalletPort(),
      blockchain: _BlockchainPort(),
      fees: _FeesPort(),
      transactions: _TransactionPort(offline: offline),
      labels: _LabelsPort(),
      legacyData: legacy ?? const _LegacyData(),
      log: log ?? _LogPort(),
    );
  }

  test(
    'regtest opens a separate store without reading or changing production',
    () async {
      final production = switch (await open()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      await production.dispose();
      final path = File('${directory.path}/payjoin.sqlite');
      final before = await path.readAsBytes();
      final legacy = _CountingLegacy();
      final isolated = switch (await open(
        profile: fixture.profile,
        legacy: legacy,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      await isolated.dispose();
      expect(legacy.reads, 0);
      expect(
        await File('${directory.path}/payjoin-regtest.sqlite').exists(),
        isTrue,
      );
      expect(await path.readAsBytes(), before);
    },
  );

  test('reopened regtest sessions retain their concrete network', () async {
    final initial = switch (await open(profile: fixture.profile)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    await initial.dispose();
    final database = openPayjoinDatabaseForTesting(
      '${directory.path}/payjoin-regtest.sqlite',
    );
    final model = PayjoinSenderModel(
      uri: 'bitcoin:bcrt1fixture?pj=https://localhost:8040/fixture',
      isTestnet: true,
      sender: '[]',
      walletId: 'regtest-wallet',
      originalPsbt: 'unused',
      originalTxId: 'original',
      amountSat: 10000,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      expireAfterSec: 3600,
    );
    await LocalPayjoinDatasource(db: database).storeSender(model);
    await database.close();
    final lifecycle = switch (await open(profile: fixture.profile)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    try {
      final sessions = switch (await lifecycle.payjoin.sessions.list(
        PayjoinSessionFilter(network: BitcoinNetwork.regtest),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      expect(sessions, hasLength(1));
      expect(sessions.single.network, BitcoinNetwork.regtest);
      for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
        final result = await lifecycle.payjoin.sessions.list(
          PayjoinSessionFilter(network: network),
        );
        expect(
          (result as Ok<List<PayjoinSession>, PayjoinFailure>).value,
          isEmpty,
        );
      }
    } finally {
      await lifecycle.dispose();
    }
  });

  test('without usable fixture trust coin selection works and Payjoin is typed unavailable', () async {
    final production = File('${directory.path}/payjoin.sqlite');
    final legacy = _CountingLegacy();
    final runtime = switch (await open(
      host: fixture.profile.hostProfile,
      legacy: legacy,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    final resumed = await runtime.resume();
    expect(resumed, isA<Err<void, PayjoinFailure>>());
    expect(
      (resumed as Err<void, PayjoinFailure>).failure,
      isA<PayjoinUnavailableFailure>(),
    );
    final empty = await runtime.payjoin.sessions.inputReservations();
    expect(
      (empty as Ok<List<PayjoinInputReservation>, PayjoinFailure>).value,
      isEmpty,
    );
    final result = await runtime.payjoin.receiver.start(
      StartPayjoinReceiver(
        walletId: 'wallet',
        network: BitcoinNetwork.regtest,
        address: 'bcrt1fixture',
      ),
    );
    expect(
      (result as Err<PayjoinReceiverSession, PayjoinFailure>).failure,
      isA<PayjoinUnavailableFailure>(),
    );
    expect(
      (await runtime.payjoin.diagnostics.relayHealth()
              as Err<PayjoinRelayHealth, PayjoinFailure>)
          .failure,
      isA<PayjoinUnavailableFailure>(),
    );
    await runtime.dispose();
    expect(legacy.reads, 0);
    expect(await production.exists(), isFalse);
    final database = openPayjoinDatabaseForTesting(
      '${directory.path}/payjoin-regtest.sqlite',
    );
    // Existing public synthetic PSBT: one input whose txid is 0x11 repeated.
    const psbt =
        'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
        'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
        'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
    await LocalPayjoinDatasource(db: database).storeSender(
      PayjoinSenderModel(
        uri: 'bitcoin:bcrt1fixture?pj=https://localhost:8040/session',
        isTestnet: true,
        sender: '[]',
        walletId: 'regtest-wallet',
        originalPsbt: psbt,
        originalTxId: 'original',
        amountSat: 10000,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expireAfterSec: 3600,
      ),
    );
    await database.close();
    final reopened = switch (await open(
      host: fixture.profile.hostProfile,
      legacy: legacy,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    try {
      final held = await reopened.payjoin.sessions.inputReservations();
      final reservations =
          (held as Ok<List<PayjoinInputReservation>, PayjoinFailure>).value;
      expect(reservations, hasLength(1));
      expect(reservations.single.network, BitcoinNetwork.regtest);
      expect(reservations.single.outpoint, (txId: '11' * 32, vout: 0));
      expect(
        await reopened.payjoin.sessions.reservedOutpoints(),
        isA<Ok<Set<Outpoint>, PayjoinFailure>>(),
      );
    } finally {
      await reopened.dispose();
    }
  });

  test('regtest reopening preserves the stored policy', () async {
    final first = switch (await open(profile: fixture.profile)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    expect(
      await first.payjoin.policy.setActionEnabled(
        PayjoinAction.send,
        enabled: false,
      ),
      isA<Ok>(),
    );
    await first.dispose();
    final second = switch (await open(profile: fixture.profile)) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    try {
      final policy = await second.payjoin.policy.load();
      expect(
        (policy as Ok<PayjoinPolicy, PayjoinFailure>).value.sendEnabled,
        isFalse,
      );
    } finally {
      await second.dispose();
    }
  });

  for (final capturedRegtest in [false, true]) {
    test(
      'stale raw runtime refuses before wallet signing regtest=$capturedRegtest',
      () async {
        var activeRegtest = capturedRegtest;
        final lifecycle = switch (await open(
          profile: capturedRegtest ? fixture.profile : null,
          wallet: _BusyWalletPort(),
          isCurrent: () async => activeRegtest == capturedRegtest,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw failure,
        };
        try {
          activeRegtest = !capturedRegtest;
          final result = await lifecycle.payjoin.sender.start(
            StartPayjoinSender(
              walletId: 'wallet',
              network: capturedRegtest
                  ? BitcoinNetwork.regtest
                  : BitcoinNetwork.mainnet,
              bip21Uri: 'bitcoin:fixture?pj=https://localhost:8040/fixture',
              unsignedOriginalPsbt: 'unused',
              amount: Sats.fromInt(10000),
              feeRate: FeeRate(1),
            ),
          );
          expect(
            (result as Err<PayjoinSenderSession, PayjoinFailure>).failure,
            isA<PayjoinUnavailableFailure>(),
          );
        } finally {
          await lifecycle.dispose();
        }
      },
    );
  }

  for (final isolated in [false, true]) {
    test(
      'runtime rejects foreign network before wallet signing regtest=$isolated',
      () async {
        final lifecycle = switch (await open(
          profile: isolated ? fixture.profile : null,
          wallet: _BusyWalletPort(),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw failure,
        };
        try {
          final result = await lifecycle.payjoin.sender.start(
            StartPayjoinSender(
              walletId: 'wallet',
              network: isolated
                  ? BitcoinNetwork.testnet
                  : BitcoinNetwork.regtest,
              bip21Uri: 'bitcoin:fixture?pj=https://localhost:8040/fixture',
              unsignedOriginalPsbt: 'unused',
              amount: Sats.fromInt(10000),
              feeRate: FeeRate(1),
            ),
          );
          expect(
            (result as Err<PayjoinSenderSession, PayjoinFailure>).failure,
            isA<PayjoinInvalidInputFailure>(),
          );
        } finally {
          await lifecycle.dispose();
        }
      },
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
      final database = openPayjoinDatabaseForTesting(
        '${directory.path}/payjoin.sqlite',
      );
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
