import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:sync/src/data/runtime/foreground_lifetime.dart';
import 'package:sync/sync.dart';

import '../../secrets/test/support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionAuthority authority;
  late SecretsInventory inventory;
  late ForegroundSession session;
  late SessionToken a1;
  late List<String> journal;

  setUp(() async {
    final fixture = await ViewFixture.create();
    addTearDown(fixture.close);
    authority = SessionAuthority();
    inventory = ok(
      await SecretsInventory.open(
        file: fixture.file,
        admission: fixture.admission,
        authority: authority,
      ),
    );
    addTearDown(inventory.close);
    session = inventory.foregroundSession;
    a1 = present(session.capture());
    journal = [];
  });

  String name(SessionToken token) => '${token.activeView}:${token.generation}';

  ForegroundLifetime<String> lifetime({
    Future<Result<String, SyncFailure>> Function(SessionToken)? open,
    Future<Result<void, SyncFailure>> Function(String)? close,
  }) => ForegroundLifetime(
    session,
    open: (grant) async {
      journal.add('open ${name(grant)}');
      return open == null ? Ok(name(grant)) : open(grant);
    },
    close: (resource) async {
      journal.add('close $resource');
      return close == null ? const Ok(null) : close(resource);
    },
  );

  Future<Result<String, SyncFailure>> work(String resource) async {
    journal.add('work $resource');
    return Ok(resource);
  }

  test('a late opening closes without admitting work', () async {
    final opening = Completer<void>();
    final finishOpen = Completer<void>();
    final machine = lifetime(
      open: (grant) async {
        if (identical(grant, a1)) {
          opening.complete();
          await finishOpen.future;
        }
        return Ok(name(grant));
      },
    );
    final previous = machine.run(a1, work);
    await opening.future;
    final b = replaceGrant(authority, 'b');
    final queued = machine.run(b, work);
    finishOpen.complete();

    expectClosed(await previous);
    expect(ok(await queued), name(b));
    expect(journal, [
      'open ${name(a1)}',
      'close ${name(a1)}',
      'open ${name(b)}',
      'work ${name(b)}',
    ]);
    ok(await machine.stop());
  });

  test(
    'replacement fences admission and drains before opening only A2',
    () async {
      final entered = Completer<void>();
      final finishWork = Completer<void>();
      final closing = Completer<void>();
      final finishClose = Completer<void>();
      final machine = lifetime(
        close: (resource) async {
          if (resource == name(a1)) {
            closing.complete();
            await finishClose.future;
          }
          return const Ok(null);
        },
      );
      final previous = machine.run(a1, (resource) async {
        journal.add('enter $resource');
        entered.complete();
        await finishWork.future;
        journal.add('leave $resource');
        return Ok(resource);
      });
      await entered.future;
      final foreign = replaceGrant(SessionAuthority(), a1.activeView);
      expect(foreign.generation, a1.generation);
      expectClosed(await machine.run(foreign, work));

      final b = replaceGrant(authority, 'b');
      expect(machine.isCurrent(a1), isFalse);
      expect(machine.capture(), same(b));
      expectClosed(await machine.run(a1, work));
      final intermediate = machine.run(b, work);
      final a2 = replaceGrant(authority, a1.activeView);
      final next = machine.run(a2, work);
      expect(journal, ['open ${name(a1)}', 'enter ${name(a1)}']);
      finishWork.complete();
      await closing.future;
      expectClosed(await previous);
      expect(journal, [
        'open ${name(a1)}',
        'enter ${name(a1)}',
        'leave ${name(a1)}',
        'close ${name(a1)}',
      ]);
      finishClose.complete();
      expectClosed(await intermediate);
      expect(ok(await next), name(a2));
      expect(journal, [
        'open ${name(a1)}',
        'enter ${name(a1)}',
        'leave ${name(a1)}',
        'close ${name(a1)}',
        'open ${name(a2)}',
        'work ${name(a2)}',
      ]);
      ok(await machine.stop());
    },
  );

  test('lock while draining skips a queued replacement', () async {
    final entered = Completer<void>();
    final finishWork = Completer<void>();
    final machine = lifetime();
    final previous = machine.run(a1, (resource) async {
      entered.complete();
      await finishWork.future;
      return Ok(resource);
    });
    await entered.future;
    final b = replaceGrant(authority, 'b');
    final queued = machine.run(b, work);
    final locking = inventory.lock();
    expect(machine.capture(), isNull);
    expect(await locking, isTrue);
    finishWork.complete();
    expectClosed(await previous);
    expectClosed(await queued);
    expect(journal, ['open ${name(a1)}', 'close ${name(a1)}']);
    final a2 = replaceGrant(authority, a1.activeView);
    expect(ok(await machine.run(a2, work)), name(a2));
    ok(await machine.stop());
  });

  test('rotation retires without any demand for the next grant', () async {
    final closing = Completer<void>();
    final confirmClose = Completer<void>();
    final machine = lifetime(
      close: (_) async {
        closing.complete();
        await confirmClose.future;
        return const Ok(null);
      },
    );
    expect(ok(await machine.run(a1, work)), name(a1));
    replaceGrant(authority, 'b');
    await closing.future;
    expect(await inventory.lock(), isTrue);
    confirmClose.complete();
    ok(await machine.stop());
    expect(journal, [
      'open ${name(a1)}',
      'work ${name(a1)}',
      'close ${name(a1)}',
    ]);
  });

  test(
    'confirmed empty opening can retry; unconfirmed opening cannot',
    () async {
      const failure = SyncBusyFailure();
      var openings = 0;
      final machine = lifetime(
        open: (_) async {
          if (++openings == 1) return const Err(failure);
          throw Exception('ownership unknown');
        },
      );
      expectFailure(await machine.run(a1, work), failure);
      expect(machine.capture(), same(a1));
      expectFailure(await machine.run(a1, work), const SyncStorageFailure());
      expect(machine.capture(), isNull);
      final b = replaceGrant(authority, 'b');
      expectClosed(await machine.run(b, work));
      expectFailure(await machine.stop(), const SyncStorageFailure());
      expect(journal, ['open ${name(a1)}', 'open ${name(a1)}']);
    },
  );

  test(
    'unconfirmed close blocks all new mounts and terminal acknowledgement',
    () async {
      const failure = SyncStorageFailure();
      final machine = lifetime(close: (_) async => const Err(failure));
      expect(ok(await machine.run(a1, work)), name(a1));
      final b = replaceGrant(authority, 'b');
      expectClosed(await machine.run(b, work));
      expect(machine.capture(), isNull);
      final a2 = replaceGrant(authority, a1.activeView);
      expectClosed(await machine.run(a2, work));
      final stopping = machine.stop();
      expect(machine.stop(), same(stopping));
      expectFailure(await stopping, failure);
      expect(journal, [
        'open ${name(a1)}',
        'work ${name(a1)}',
        'close ${name(a1)}',
      ]);
    },
  );

  test(
    'terminal stop coalesces, drains every admission, and never rotates',
    () async {
      final bothEntered = Completer<void>();
      final oneLeft = Completer<void>();
      final otherLeft = Completer<void>();
      final machine = lifetime();
      var entered = 0;
      Future<Result<String, SyncFailure>> hold(
        String resource,
        Completer<void> leave,
      ) async {
        journal.add('enter ${++entered}');
        if (entered == 2) bothEntered.complete();
        await leave.future;
        return Ok(resource);
      }

      final one = machine.run(a1, (resource) => hold(resource, oneLeft));
      final other = machine.run(a1, (resource) => hold(resource, otherLeft));
      await bothEntered.future;
      final stopping = machine.stop();
      expect(machine.stop(), same(stopping));
      expect(machine.capture(), isNull);
      expectClosed(await machine.run(a1, work));
      final b = replaceGrant(authority, 'b');
      expectClosed(await machine.run(b, work));
      oneLeft.complete();
      expectClosed(await one);
      expect(journal, ['open ${name(a1)}', 'enter 1', 'enter 2']);
      otherLeft.complete();
      expectClosed(await other);
      ok(await stopping);
      expect(machine.stop(), same(stopping));
      expect(journal, [
        'open ${name(a1)}',
        'enter 1',
        'enter 2',
        'close ${name(a1)}',
      ]);
    },
  );
}

void expectClosed<T>(Result<T, SyncFailure> result) {
  expect(
    result,
    isA<Err<T, SyncFailure>>().having(
      (result) => result.failure,
      'failure',
      isA<SyncClosedFailure>(),
    ),
  );
}

void expectFailure<T>(Result<T, SyncFailure> result, SyncFailure failure) =>
    expect(
      result,
      isA<Err<T, SyncFailure>>().having(
        (result) => result.failure,
        'failure',
        same(failure),
      ),
    );
