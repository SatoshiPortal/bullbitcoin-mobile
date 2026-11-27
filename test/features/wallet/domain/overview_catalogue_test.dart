import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, NetworkEnv;
import 'package:sync/sync.dart';

final class _Reader implements OverviewFinancialReader {
  final reads = <OverviewFinancialRequest>[];
  final replies = <Completer<OverviewFinancialRead>>[];

  @override
  Future<OverviewFinancialRead> read(OverviewFinancialRequest request) {
    reads.add(request);
    final reply = Completer<OverviewFinancialRead>();
    replies.add(reply);
    return reply.future;
  }

  void reply(int n, int? amount, {OverviewFinancialRequest? as}) =>
      replies[n].complete((request: as ?? reads[n], balanceSat: amount));
}

final _btc = WalletKey(id: 'same', network: BitcoinNetwork.regtest);
final _liquid = WalletKey(id: 'same', network: LiquidNetwork.regtest);
final _main = WalletKey(id: 'same', network: BitcoinNetwork.mainnet);

WalletRevision _stamp(WalletKey key, {int generation = 4, int revision = 1}) =>
    WalletRevision(key: key, generation: generation, revision: revision);

OverviewCatalogueEntry _entry(
  WalletKey key, {
  String? label,
  bool local = true,
  bool isDefault = false,
}) => (
  revision: _stamp(key),
  label: label,
  isDefault: isDefault,
  signsLocally: local,
);

void main() {
  late _Reader reader;
  late OverviewCatalogue catalogue;

  setUp(() {
    reader = _Reader();
    catalogue = OverviewCatalogue(reader);
    addTearDown(catalogue.close);
  });

  OverviewCatalogueGrant replace({NetworkEnv? env, int generation = 7}) {
    final grant = catalogue.replacing(env ?? _btc.network.env, generation);
    if (grant == null) throw StateError('Projection is closed');
    return grant;
  }

  void publish(
    OverviewCatalogueGrant grant,
    List<OverviewCatalogueEntry> rows,
  ) => catalogue.publish(grant, OverviewCatalogueCompleteness.complete, rows);

  test(
    'revocation clears synchronously and an A1 read or tap cannot return in A2',
    () async {
      final first = replace();
      publish(first, [_entry(_btc, isDefault: true)]);
      final obsolete = catalogue.snapshot.rows.single;
      expect(catalogue.selectLocal(obsolete)?.isDefault, isTrue);

      catalogue.revoke(first);
      expect(catalogue.snapshot.status, OverviewCatalogueStatus.revoked);
      expect(catalogue.snapshot.rows, isEmpty);
      expect(catalogue.selectLocal(obsolete), isNull);

      final second = replace(generation: 8);
      publish(second, [_entry(_liquid, label: 'B')]);
      final third = replace();
      publish(third, [_entry(_btc, label: 'A2')]);
      expect(third.generation, first.generation);
      expect(third.environment, first.environment);
      expect(third, isNot(same(first)));
      reader.reply(2, 7);
      reader.reply(1, 80);
      reader.reply(0, 90);
      await pumpEventQueue();
      expect(catalogue.snapshot.rows.single.balanceSat, 7);
      expect(catalogue.selectLocal(obsolete), isNull);
      expect(catalogue.selectLocal(catalogue.snapshot.rows.single), (
        key: _btc,
        label: 'A2',
        isDefault: false,
      ));
    },
  );

  test(
    'environment replacement and close reject queued values and former taps',
    () async {
      final a = replace();
      publish(a, [_entry(_btc)]);
      final old = catalogue.snapshot.rows.single;
      final seen = <OverviewCatalogueStatus>[];
      final subscription = catalogue.changes.listen((_) {
        seen.add(catalogue.snapshot.status);
      });
      addTearDown(subscription.cancel);
      final b = replace(env: _main.network.env);
      expect(catalogue.snapshot.rows, isEmpty);
      publish(a, [_entry(_btc)]);
      publish(b, [_entry(_btc), _entry(_main)]);
      expect(catalogue.snapshot.status, OverviewCatalogueStatus.partial);
      final row = catalogue.snapshot.rows.single;
      expect(row.entry.revision.key, _main);
      expect(catalogue.selectLocal(old), isNull);
      expect(reader.reads.map((request) => request.revision.key), [
        _btc,
        _main,
      ]);
      final closing = catalogue.close();
      expect(catalogue.snapshot.status, OverviewCatalogueStatus.closed);
      expect(catalogue.snapshot.rows, isEmpty);
      expect(catalogue.selectLocal(row), isNull);
      reader.reply(0, 10);
      reader.reply(1, 20);
      await closing;
      await pumpEventQueue();
      expect(seen, isNotEmpty);
      expect(seen, everyElement(OverviewCatalogueStatus.closed));
      expect(catalogue.replacing(_main.network.env, 9), isNull);
    },
  );

  test(
    'preserves interleaved catalogue order, locality and null versus zero',
    () async {
      final third = WalletKey(id: 'other', network: BitcoinNetwork.regtest);
      final grant = replace();
      publish(grant, [
        _entry(_liquid, local: false),
        _entry(_btc, isDefault: true),
        _entry(third, label: ''),
      ]);
      reader.reply(2, 20);
      reader.reply(0, null);
      reader.reply(1, 0);
      await pumpEventQueue();
      final rows = catalogue.snapshot.rows;
      expect(rows.map((row) => row.entry.revision.key), [_liquid, _btc, third]);
      expect(rows.map((row) => row.balanceSat), [null, 0, 20]);
      expect(rows.first.financialStatus, OverviewFinancialStatus.unreadable);
      expect(rows[1].financialStatus, OverviewFinancialStatus.available);
      expect(catalogue.selectLocal(rows.first), isNull);
      expect(catalogue.selectLocal(rows[1]), (
        key: _btc,
        label: null,
        isDefault: true,
      ));
      expect(catalogue.selectLocal(rows[2])?.label, '');
    },
  );

  test('partial, unreadable, and authoritatively empty catalogues differ', () {
    final partial = replace();
    catalogue.publish(partial, OverviewCatalogueCompleteness.partial, []);
    expect(catalogue.snapshot.status, OverviewCatalogueStatus.partial);
    final unreadable = replace();
    catalogue.publish(unreadable, OverviewCatalogueCompleteness.unreadable, [
      _entry(_btc),
    ]);
    expect(catalogue.snapshot.status, OverviewCatalogueStatus.unreadable);
    expect(catalogue.snapshot.rows, isEmpty);
    final empty = replace();
    publish(empty, []);
    expect(catalogue.snapshot.status, OverviewCatalogueStatus.empty);
    publish(empty, [_entry(_btc)]);
    expect(catalogue.snapshot.rows, isEmpty);
    expect(reader.reads, isEmpty);
  });

  test(
    'checks exact scope and stamp and never resurrects a removed key',
    () async {
      final expired = replace();
      final grant = replace();
      publish(grant, [_entry(_btc), _entry(_liquid)]);
      final old = catalogue.snapshot.rows.first;
      void change(
        OverviewCatalogueGrant owner,
        WalletRevision stamp, [
        WalletLifecycle life = WalletLifecycle.active,
      ]) {
        catalogue.revised(
          owner,
          WalletRevisionState(stamp: stamp, lifecycle: life),
        );
      }

      change(expired, _stamp(_btc, revision: 2));
      change(grant, _stamp(_main, revision: 2));
      change(grant, _stamp(_btc, generation: 3, revision: 2));
      change(grant, _stamp(_btc));
      expect(reader.reads, hasLength(2));
      final current = _stamp(_btc, revision: 2);
      change(grant, current);
      expect(reader.reads.last, (grant: grant, revision: current));
      expect(catalogue.selectLocal(old), isNull);

      reader.reply(
        2,
        700,
        as: (grant: grant, revision: _stamp(_liquid, revision: 2)),
      );
      reader.reply(0, 900);
      reader.reply(1, 0);
      await pumpEventQueue();
      expect(catalogue.snapshot.rows.first.balanceSat, isNull);
      expect(catalogue.snapshot.rows.last.balanceSat, 0);

      change(grant, _stamp(_btc, revision: 3), WalletLifecycle.deleted);
      change(grant, _stamp(_btc, revision: 4));
      expect(catalogue.snapshot.rows.single.entry.revision.key, _liquid);
      expect(reader.reads, hasLength(3));
      catalogue.revoke(grant);
      change(grant, _stamp(_liquid, revision: 3));
      expect(catalogue.snapshot.rows, isEmpty);
      expect(reader.reads, hasLength(3));
    },
  );

  test('pending and next-generation deletion retire rows before native reads settle', () async {
    final grant = replace();
    publish(grant, [_entry(_btc), _entry(_liquid)]);
    final before = catalogue.snapshot.rows;
    catalogue.revised(
      grant,
      WalletRevisionState(
        stamp: _stamp(_btc),
        lifecycle: WalletLifecycle.pendingWrite,
      ),
    );
    catalogue.revised(
      grant,
      WalletRevisionState(
        stamp: _stamp(_liquid, generation: 5),
        lifecycle: WalletLifecycle.deleted,
      ),
    );
    expect(catalogue.snapshot.rows, isEmpty);
    for (final row in before) {
      expect(catalogue.selectLocal(row), isNull);
      catalogue.revised(
        grant,
        WalletRevisionState(
          stamp: _stamp(row.entry.revision.key, generation: 5, revision: 2),
          lifecycle: WalletLifecycle.active,
        ),
      );
    }
    reader.reply(0, 1);
    reader.reply(1, 2);
    await pumpEventQueue();
    expect(reader.reads, hasLength(2));
    expect(catalogue.snapshot.rows, isEmpty);
    expect(catalogue.snapshot.status, OverviewCatalogueStatus.partial);
  });
}
