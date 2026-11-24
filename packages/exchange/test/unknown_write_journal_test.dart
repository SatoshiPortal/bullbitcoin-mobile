import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/storage/exchange_database.dart';
import 'package:exchange/src/data/unknown_write_journal_store.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Expected Ok, got $failure'),
};

const _confirm = UnknownWriteDraft(
  kind: UnknownWriteKind.buyConfirm,
  environment: ExchangeEnvironment.testnet,
  sessionEpoch: 3,
  orderId: 'o-1',
  request: {'orderId': 'o-1'},
);

const _dca = UnknownWriteDraft(
  kind: UnknownWriteKind.dcaCreate,
  environment: ExchangeEnvironment.testnet,
  request: {'amount': '25.5', 'address': 'tb1qdca'},
);

const _mainnet = UnknownWriteDraft(
  kind: UnknownWriteKind.limitOrderCreate,
  environment: ExchangeEnvironment.mainnet,
  request: {'address': 'bc1q'},
);

void main() {
  final journals = <String, (UnknownWriteJournal, Future<void> Function())>{};

  setUp(() {
    final database = ExchangeDatabase(NativeDatabase.memory());
    var id = 0;
    journals['drift'] = (
      DriftUnknownWriteJournal(database, newId: () => 'id-${id++}'),
      database.close,
    );
    journals['memory'] = (InMemoryUnknownWriteJournal(), () async {});
  });

  tearDown(() async {
    for (final (_, close) in journals.values) {
      await close();
    }
  });

  for (final name in ['drift', 'memory']) {
    group(name, () {
      test('a recorded write is open, with what was sent', () async {
        final (journal, _) = journals[name]!;
        final recorded = await withClock(
          Clock.fixed(DateTime.utc(2026, 11, 23, 10)),
          () async => _ok(await journal.record(_confirm)),
        );

        final open = _ok(await journal.open(ExchangeEnvironment.testnet));

        expect(open, hasLength(1));
        final entry = open.single;
        expect(entry.id, recorded.id);
        expect(entry.kind, UnknownWriteKind.buyConfirm);
        expect(entry.environment, ExchangeEnvironment.testnet);
        expect(entry.sessionEpoch, 3);
        expect(entry.orderId, 'o-1');
        expect(entry.request, {'orderId': 'o-1'});
        expect(entry.recordedAt, DateTime.utc(2026, 11, 23, 10));
      });

      test('open lists one environment, oldest first', () async {
        final (journal, _) = journals[name]!;
        await withClock(
          Clock.fixed(DateTime.utc(2026, 11, 23, 10)),
          () => journal.record(_confirm),
        );
        await withClock(
          Clock.fixed(DateTime.utc(2026, 11, 23, 11)),
          () => journal.record(_dca),
        );
        await journal.record(_mainnet);

        final testnet = _ok(await journal.open(ExchangeEnvironment.testnet));
        final mainnet = _ok(await journal.open(ExchangeEnvironment.mainnet));

        expect(testnet.map((e) => e.kind), [
          UnknownWriteKind.buyConfirm,
          UnknownWriteKind.dcaCreate,
        ]);
        expect(mainnet.map((e) => e.kind), [UnknownWriteKind.limitOrderCreate]);
      });

      test('a settled entry leaves the open set, the others stay', () async {
        final (journal, _) = journals[name]!;
        final first = _ok(await journal.record(_confirm));
        final second = _ok(await journal.record(_dca));

        _ok(await journal.settle(first.id, UnknownWriteSettlement.applied));

        final open = _ok(await journal.open(ExchangeEnvironment.testnet));
        expect(open.map((e) => e.id), [second.id]);
      });

      test(
        'settling twice or settling an unknown id changes nothing',
        () async {
          final (journal, _) = journals[name]!;
          final entry = _ok(await journal.record(_confirm));

          _ok(
            await journal.settle(entry.id, UnknownWriteSettlement.notApplied),
          );
          _ok(await journal.settle(entry.id, UnknownWriteSettlement.applied));
          _ok(await journal.settle('nope', UnknownWriteSettlement.applied));

          expect(_ok(await journal.open(ExchangeEnvironment.testnet)), isEmpty);
        },
      );
    });
  }

  test('every kind and settlement keeps its stored name', () {
    expect(
      {for (final k in UnknownWriteKind.values) k: k.wire},
      {
        UnknownWriteKind.buyConfirm: 'buy_confirm',
        UnknownWriteKind.withdrawConfirm: 'withdraw_confirm',
        UnknownWriteKind.accelerate: 'accelerate',
        UnknownWriteKind.dcaCreate: 'dca_create',
        UnknownWriteKind.limitOrderCreate: 'limit_order_create',
        UnknownWriteKind.defaultWalletSave: 'default_wallet_save',
        UnknownWriteKind.recipientCreate: 'recipient_create',
        UnknownWriteKind.preferencesSave: 'preferences_save',
      },
    );
    for (final kind in UnknownWriteKind.values) {
      expect(UnknownWriteKind.fromWire(kind.wire), kind);
    }
    expect(UnknownWriteKind.fromWire('other'), isNull);
    expect(UnknownWriteSettlement.values.map((s) => s.wire), [
      'applied',
      'not_applied',
      'order_ended',
      'expired',
    ]);
  });

  group('schema', () {
    test('a fresh database has the journal table at schema 2', () async {
      final database = ExchangeDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final table = await database
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' "
            "AND name = 'unknown_writes'",
          )
          .getSingleOrNull();

      expect(version.read<int>('user_version'), 2);
      expect(table, isNotNull);
    });

    test('schema 1 upgrades to 2 and keeps its rows', () async {
      final database = ExchangeDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE exchange_api_credentials (environment TEXT NOT NULL '
              "CHECK (environment IN ('mainnet', 'testnet')), "
              'encoded_record TEXT NULL, PRIMARY KEY (environment))',
            );
            raw.execute(
              'CREATE TABLE exchange_basic_auth (settings_id INTEGER NOT NULL, '
              'username TEXT NULL, password TEXT NULL, '
              'PRIMARY KEY (settings_id))',
            );
            raw.execute(
              'CREATE TABLE legacy_import_receipts (id TEXT NOT NULL, '
              'PRIMARY KEY (id))',
            );
            raw.execute(
              "INSERT INTO legacy_import_receipts (id) VALUES ('fresh-v1/exchange')",
            );
            raw.userVersion = 1;
          },
        ),
      );
      addTearDown(database.close);

      final journal = DriftUnknownWriteJournal(database);
      final entry = _ok(await journal.record(_confirm));

      expect(
        _ok(await journal.open(ExchangeEnvironment.testnet)).single.id,
        entry.id,
      );
      final receipts = await database
          .customSelect('SELECT id FROM legacy_import_receipts')
          .get();
      expect(receipts.map((r) => r.read<String>('id')), ['fresh-v1/exchange']);
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 2);
    });
  });
}
