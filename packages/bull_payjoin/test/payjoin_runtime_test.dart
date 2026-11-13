import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_sqlite/bull_sqlite.dart' show SqliteCipher;
import 'package:sqlite3/sqlite3.dart';
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

  String databasePath() => '${directory.path}/payjoin.sqlite';
  final key = DatabaseKey(Uint8List.fromList(List<int>.generate(32, (i) => i)));

  Future<Result<PayjoinLifecycle, PayjoinFailure>> open({
    PayjoinLogPort? log,
    DatabaseKey? databaseKey,
  }) {
    return openPayjoin(
      databasePath: databasePath(),
      databaseKey: databaseKey ?? key,
      wallet: _WalletPort(),
      blockchain: _BlockchainPort(),
      fees: _FeesPort(),
      transactions: _TransactionPort(),
      labels: _LabelsPort(),
      legacyData: const _LegacyData(),
      log: log ?? _LogPort(),
    );
  }

  test(
    'writer contention preserves the active database and reserved inputs',
    () async {
      const psbt =
          'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
          'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
          'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
      final initial = switch (await open()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      await initial.dispose();
      final path = '${directory.path}/payjoin.sqlite';
      final held = sqlite3.open(path);
      SqliteCipher.key(held, key);
      held.execute(
        'INSERT INTO payjoin_senders '
        '(uri,is_testnet,sender,wallet_id,original_psbt,original_tx_id,amount_sat,'
        'created_at,expire_after_sec,is_expired,is_completed,is_aborted) '
        "VALUES ('bitcoin:tb1qreserved?pj=https://payjo.in',1,'[]','wallet',?,'original',10000,?,3600,0,0,0)",
        [psbt, DateTime.now().millisecondsSinceEpoch ~/ 1000],
      );

      held.execute('PRAGMA journal_mode = DELETE');
      held.execute('BEGIN EXCLUSIVE');
      try {
        final log = _LogPort();
        final result = await open(log: log);
        expect(
          log.events.any(
            (event) => event.error.toString().contains('SqliteBusyFailure'),
          ),
          isTrue,
          reason: 'A real SQLite lock must cause the refusal',
        );

        if (result case Ok(:final value)) await value.dispose();
        expect(
          result,
          isA<Err<PayjoinLifecycle, PayjoinFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<PayjoinMigrationFailure>(),
          ),
        );
        expect(
          directory.listSync().where((f) => f.path.contains('.unreadable-')),
          isEmpty,
        );
      } finally {
        held.close();
      }
      final restored = switch (await open()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      addTearDown(restored.dispose);
      expect(
        await restored.payjoin.sessions.reservedOutpoints(),
        isA<Ok<Set<Outpoint>, PayjoinFailure>>().having(
          (r) => r.value,
          'reserved inputs',
          contains((txId: '11' * 32, vout: 0)),
        ),
      );
      final check = sqlite3.open(path);
      SqliteCipher.key(check, key);
      try {
        final row = check
            .select('SELECT original_psbt,sender FROM payjoin_senders')
            .single;
        expect(row['original_psbt'], psbt);
        expect(row['sender'], '[]');
      } finally {
        check.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

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

  group('storage', () {
    Future<PayjoinLifecycle> opened() async => switch (await open()) {
      Ok(:final value) => value,
      Err(:final failure) => fail('did not open: $failure'),
    };

    List<String> files() =>
        directory.listSync().map((e) => e.uri.pathSegments.last).toList()
          ..sort();

    test('is created encrypted', () async {
      final lifecycle = await opened();
      await lifecycle.dispose();
      final header = String.fromCharCodes(
        File(databasePath()).readAsBytesSync().take(15),
      );
      expect(header, isNot('SQLite format 3'));
    });

    test('a wrong key is refused and nothing is moved aside', () async {
      await (await opened()).dispose();
      final before = files();
      final wrong = DatabaseKey(Uint8List.fromList(List<int>.filled(32, 9)));
      final result = await open(databaseKey: wrong);
      expect(result, isA<Err<PayjoinLifecycle, PayjoinFailure>>());
      expect(files(), before);
      expect(files().where((f) => f.contains('unreadable')), isEmpty);
      // Still opens with its own key: nothing was lost.
      await (await opened()).dispose();
    });

    test('a plaintext file is refused, never quarantined', () async {
      File(
        databasePath(),
      ).writeAsStringSync('SQLite format 3\u0000${'x' * 200}');
      final result = await open();
      expect(result, isA<Err<PayjoinLifecycle, PayjoinFailure>>());
      expect(files(), ['payjoin.sqlite']);
    });

    test(
      'a future encrypted schema is refused without retiring its family',
      () async {
        await (await opened()).dispose();
        final raw = sqlite3.open(databasePath());
        SqliteCipher.key(raw, key);
        raw.execute('CREATE TABLE future_sentinel (value TEXT NOT NULL)');
        raw.execute("INSERT INTO future_sentinel VALUES ('retained')");
        raw.execute('PRAGMA journal_mode = DELETE');
        raw.execute('PRAGMA user_version = 99');
        raw.close();
        final before = File(databasePath()).readAsBytesSync();
        final family = files();
        final result = await open();
        if (result case Ok(:final value)) await value.dispose();
        expect(result, isA<Err<PayjoinLifecycle, PayjoinFailure>>());
        expect(files(), family);
        expect(File(databasePath()).readAsBytesSync(), before);
        final check = sqlite3.open(databasePath());
        SqliteCipher.key(check, key);
        try {
          expect(
            check.select('PRAGMA user_version').single['user_version'],
            99,
          );
          expect(
            check.select('SELECT value FROM future_sentinel').single['value'],
            'retained',
          );
        } finally {
          check.close();
        }
      },
    );

    test('an interrupted quarantine is finished before the open', () async {
      await (await opened()).dispose();
      File(
        '${databasePath()}.retire-pending',
      ).writeAsStringSync('quarantine:.unreadable-1');
      final lifecycle = await opened();
      await lifecycle.dispose();
      expect(files(), contains('payjoin.sqlite.unreadable-1'));
      expect(files(), isNot(contains('payjoin.sqlite.retire-pending')));
    });
  });
}
