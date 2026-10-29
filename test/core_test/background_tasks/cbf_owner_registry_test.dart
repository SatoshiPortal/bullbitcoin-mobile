import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:bb_mobile/core/background_tasks/cbf_background_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/core/background_tasks/cbf_owner_registry.dart';

const _foreground = 'bull.cbf.foreground.active';

Future<void> _foregroundOwner(SendPort ready) async {
  final presence = CbfForegroundPresence();
  await Future<void>.sync(() => presence.setActive(true));
  ready.send(true);
}

Future<void> _backgroundOwner(List<Object?> args) async {
  final name = args[0] as String;
  final ready = args[1] as SendPort;
  final armed = args[2] as bool;
  final lease = args[3] as Duration?;
  final registration = await CbfOwnerRegistration.acquire(
    name,
    onStop: () async => false,
  );
  if (registration == null) {
    ready.send(false);
    return;
  }
  if (armed) {
    await registration.armNative(nativeTerminationBoundAfterOwnerExit: lease);
  }
  final monitor = args.length > 4 ? args[4] as SendPort? : null;
  if (monitor != null && !await registration.trackNativeNode(monitor)) {
    ready.send(false);
    return;
  }
  ready.send(true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'dead foreground owner before native admission is recoverable',
    () async {
      final ready = ReceivePort(), exited = ReceivePort();
      final owner = await Isolate.spawn(
        _foregroundOwner,
        ready.sendPort,
        onExit: exited.sendPort,
      );
      final replacement = CbfForegroundPresence();
      try {
        expect(await ready.first, isTrue);
        owner.kill(priority: Isolate.immediate);
        await exited.first;
        for (
          var i = 0;
          i < 50 && IsolateNameServer.lookupPortByName(_foreground) != null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(
          IsolateNameServer.lookupPortByName(_foreground),
          isNull,
          reason: 'a dead quiescent owner must release its registry identity',
        );
        await Future<void>.sync(() => replacement.setActive(true));
        expect(IsolateNameServer.lookupPortByName(_foreground), isNotNull);
      } finally {
        owner.kill(priority: Isolate.immediate);
        ready.close();
        exited.close();
        await Future<void>.sync(replacement.dispose);
        IsolateNameServer.removePortNameMapping(_foreground);
      }
    },
  );
  for (final lease in [null, const Duration(milliseconds: 150)]) {
    test(
      'dead armed background owner requires native termination proof ($lease)',
      () async {
        const name = 'bull.cbf.background.policy';
        final ready = ReceivePort(), exited = ReceivePort();
        final child = await Isolate.spawn(_backgroundOwner, [
          name,
          ready.sendPort,
          true,
          lease,
        ], onExit: exited.sendPort);
        try {
          expect(await ready.first, isTrue);
          child.kill(priority: Isolate.immediate);
          await exited.first;
          expect(await stopActiveCbfBackgroundSync(), isFalse);
          expect(
            await CbfOwnerRegistration.acquire(name, onStop: () async => true),
            isNull,
          );
          if (lease != null) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            expect(await stopActiveCbfBackgroundSync(), isTrue);
            final replacement = await CbfOwnerRegistration.acquire(
              name,
              onStop: () async => true,
            );
            expect(replacement, isNotNull);
            await replacement?.release();
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            expect(
              await stopActiveCbfBackgroundSync(),
              isFalse,
              reason:
                  'a Dart liveness timeout cannot certify native termination',
            );
          }
        } finally {
          child.kill(priority: Isolate.immediate);
          ready.close();
          exited.close();
          // The no-lease case deliberately leaves an addressable quarantine in
          // this isolated test process; it must never gain production admission.
          IsolateNameServer.removePortNameMapping(name);
        }
      },
    );
  }
  test(
    'dead quiescent background owner releases the actual policy name',
    () async {
      const name = 'bull.cbf.background.policy';
      final ready = ReceivePort(), exited = ReceivePort();
      final child = await Isolate.spawn(_backgroundOwner, [
        name,
        ready.sendPort,
        false,
        null,
      ], onExit: exited.sendPort);
      try {
        expect(await ready.first, isTrue);
        child.kill(priority: Isolate.immediate);
        await exited.first;
        for (
          var i = 0;
          i < 50 && IsolateNameServer.lookupPortByName(name) != null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(await stopActiveCbfBackgroundSync(), isTrue);
        final replacement = await CbfOwnerRegistration.acquire(
          name,
          onStop: () async => true,
        );
        expect(replacement, isNotNull);
        await replacement?.release();
      } finally {
        child.kill(priority: Isolate.immediate);
        ready.close();
        exited.close();
      }
    },
  );
  test(
    'a failed native join retains the identity until acknowledged',
    () async {
      const name = 'bull.cbf.registry.join-test';
      var terminated = false;
      final owner = await CbfOwnerRegistration.acquire(
        name,
        onStop: () async => terminated,
      );
      expect(await owner?.armNative(), isTrue);
      expect(await CbfOwnerRegistration.stop(name), isFalse);
      expect(await owner?.release(), isFalse);
      expect(
        await CbfOwnerRegistration.acquire(name, onStop: () async => true),
        isNull,
      );
      terminated = true;
      expect(await CbfOwnerRegistration.stop(name), isTrue);
      expect(await owner?.release(), isTrue);
      final replacement = await CbfOwnerRegistration.acquire(
        name,
        onStop: () async => true,
      );
      expect(replacement, isNotNull);
      // The retired owner cannot remove its successor's mapping.
      final successor = IsolateNameServer.lookupPortByName(name);
      expect(successor, isNotNull);
      await replacement?.release();
    },
  );
  test(
    'lease bound cannot release an owner with an unacknowledged DNS join',
    () async {
      const name = 'bull.cbf.registry.dns-test';
      final monitor = ReceivePort(),
          ready = ReceivePort(),
          exited = ReceivePort();
      SendPort? witness;
      final subscription = monitor.listen((message) {
        final command = message as List;
        witness = command[1] as SendPort;
        (command.last as SendPort).send(true);
      });
      final child = await Isolate.spawn(_backgroundOwner, [
        name,
        ready.sendPort,
        true,
        const Duration(milliseconds: 50),
        monitor.sendPort,
      ], onExit: exited.sendPort);
      CbfOwnerRegistration? replacement;
      try {
        expect(await ready.first, isTrue);
        child.kill(priority: Isolate.immediate);
        await exited.first;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(await CbfOwnerRegistration.stop(name), isFalse);
        expect(
          await CbfOwnerRegistration.acquire(name, onStop: () async => true),
          isNull,
        );
        final nativeWitness = witness;
        expect(nativeWitness, isNotNull);
        nativeWitness?.send(['native-terminated', monitor.sendPort]);
        for (
          var i = 0;
          i < 50 && IsolateNameServer.lookupPortByName(name) != null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        replacement = await CbfOwnerRegistration.acquire(
          name,
          onStop: () async => true,
        );
        expect(replacement, isNotNull);
      } finally {
        child.kill(priority: Isolate.immediate);
        await replacement?.release();
        await subscription.cancel();
        monitor.close();
        ready.close();
        exited.close();
      }
    },
  );
}
