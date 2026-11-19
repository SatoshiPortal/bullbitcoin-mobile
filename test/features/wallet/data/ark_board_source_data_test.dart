import 'dart:async';

import 'package:bb_mobile/features/wallet/data/ark_board_source_data.dart';
import 'package:bb_mobile/features/wallet/data/ark_display_data.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_source_test_support.dart';

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw StateError('Board source test refused ${result.runtimeType}'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BoardSourceRig rig;
  late WalletArkBoardSourceData source;
  late WalletArkDisplayData display;
  final waits = <({Completer<void> entered, Completer<String> reply})>[];
  var active = true;
  Future<Result<String, ArkFailure>> Function()? selection;
  late StreamController<String> currencyChanges;
  final gates = <Completer<String>>[];
  Future<void> open({bool funded = true}) async {
    rig = await boardSourceRig(funded: funded);
    active = true;
    selection = null;
    waits.clear();
    gates.clear();
    currencyChanges = StreamController<String>.broadcast(sync: true);
    display = WalletArkDisplayData(
      runtime: rig.runtime,
      account: rig.opened.account,
      currencyChanges: currencyChanges.stream,
      selectedSource: (_) async => Ok(rig.row.id),
      isActive: () => active,
      currency: () async {
        if (waits.isEmpty) return 'unsupported-fixture-currency';
        final waiting = waits.removeAt(0);
        waiting.entered.complete();
        return waiting.reply.future;
      },
    );
    source = WalletArkBoardSourceData(
      display: display,
      sync: rig.source,
      runtime: rig.runtime,
      metadata: rig.metadata,
      account: rig.opened.account,
      selectedSource: (_) async {
        final selected = selection;
        return selected == null ? Ok(rig.row.id) : await selected();
      },
      isActive: () => active,
    );
    addTearDown(() async {
      for (final gate in gates) {
        if (!gate.isCompleted) gate.complete('unsupported-fixture-currency');
      }
      await source.close();
      await display.close();
      await currencyChanges.close();
    });
  }

  ({Completer<void> entered, Completer<String> reply}) hold() {
    final waiting = (entered: Completer<void>(), reply: Completer<String>());
    waits.add(waiting);
    gates.add(waiting.reply);
    return waiting;
  }

  test(
    'one exact scan serves concurrent refresh; passive reads never scan',
    () async {
      await open();
      expect(await source.read(rig.opened.account), isA<Err>());
      var scans = 0;
      final subscription = rig.source.started.listen((_) => scans++);
      addTearDown(subscription.cancel);
      final waiting = hold();
      final a = source.refresh(rig.opened.account);
      final b = source.refresh(rig.opened.account);
      expect(a, same(b));
      await waiting.entered.future;
      waiting.reply.complete('unsupported-fixture-currency');
      final value = _ok(await a);
      expect(value.available, Sats.fromInt(100000));
      expect(source.accepts(value), isTrue);
      _ok(await b);
      _ok(await source.read(rig.opened.account));
      expect(scans, 1);
      active = false;
      expect(source.accepts(value), isFalse);
    },
  );

  for (final refreshNewEpoch in [false, true]) {
    test(
      'late read cannot replace or revoke a newer publication refresh=$refreshNewEpoch',
      () async {
        await open();
        _ok(await source.refresh(rig.opened.account));
        final waiting = hold();
        final old = source.read(rig.opened.account);
        await waiting.entered.future;
        final current = _ok(
          await (refreshNewEpoch
              ? source.refresh(rig.opened.account)
              : source.read(rig.opened.account)),
        );
        expect(source.accepts(current), isTrue);
        waiting.reply.complete('unsupported-fixture-currency');
        expect(await old, isA<Err>());
        expect(source.accepts(current), isTrue);
        expect(
          _ok(await source.read(rig.opened.account)).available,
          Sats.fromInt(100000),
        );
      },
    );
  }

  test('generation replacement after scan but before publication requires a new exact scan', () async {
    await open();
    final waiting = hold();
    final refreshing = source.refresh(rig.opened.account);
    await waiting.entered.future;
    final key = (await rig.runtime.wallet(rig.row.id)).key;
    final original = _ok(await rig.runtime.readRevision(key)).stamp;
    await rig.runtime.delete(rig.row);
    await rig.runtime.create(rig.row);
    final replaced = _ok(await rig.runtime.readRevision(key)).stamp;
    expect(replaced.generation, greaterThan(original.generation));
    waiting.reply.complete('unsupported-fixture-currency');
    expect(await refreshing, isA<Err>());
    expect(await source.read(rig.opened.account), isA<Err>());
    expect(
      _ok(await source.refresh(rig.opened.account)).available,
      Sats.fromInt(100000),
    );
  });

  test('failed scan is unknown until explicit retry succeeds', () async {
    await open();
    rig.connections.urls[0] = 'tcp://127.0.0.1:1';
    expect(await source.refresh(rig.opened.account), isA<Err>());
    expect(await source.read(rig.opened.account), isA<Err>());
    rig.connections.urls[0] = rig.server.url;
    expect(
      _ok(await source.refresh(rig.opened.account)).available,
      Sats.fromInt(100000),
    );
  });
  test(
    'a successful scan of a genuinely empty source keeps exact zero',
    () async {
      await open(funded: false);
      final value = _ok(await source.refresh(rig.opened.account));
      expect(value.available, Sats.zero);
      expect(source.accepts(value), isTrue);
    },
  );

  test(
    'an invalidation event retires an in-flight read without erasing its scan',
    () async {
      await open();
      _ok(await source.refresh(rig.opened.account));
      final waiting = hold();
      final old = source.read(rig.opened.account);
      await waiting.entered.future;
      currencyChanges.add('changed');
      await Future<void>.delayed(Duration.zero);
      waiting.reply.complete('unsupported-fixture-currency');
      expect(await old, isA<Err>());
      expect(
        _ok(await source.read(rig.opened.account)).available,
        Sats.fromInt(100000),
      );
    },
  );
  test('current selection exception revokes publication; a superseded exception cannot', () async {
    await open();
    final initial = _ok(await source.refresh(rig.opened.account));
    selection = () async => throw Exception('selection unavailable');
    expect(await source.read(rig.opened.account), isA<Err>());
    expect(source.accepts(initial), isFalse);
    selection = null;
    _ok(await source.read(rig.opened.account));
    final entered = Completer<void>();
    final suspended = Completer<Result<String, ArkFailure>>();
    selection = () {
      entered.complete();
      return suspended.future;
    };
    final old = source.read(rig.opened.account);
    await entered.future;
    selection = null;
    final current = _ok(await source.read(rig.opened.account));
    suspended.completeError(Exception('obsolete selection unavailable'));
    expect(await old, isA<Err>());
    expect(source.accepts(current), isTrue);
  });
}
