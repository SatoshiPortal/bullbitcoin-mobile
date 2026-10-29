import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;

/// Keeps submission callbacks alive across owner exit and witnesses native join.
final class CbfNativeOwner {
  final SendPort commands;

  CbfNativeOwner._(this.commands);

  static Future<CbfNativeOwner> start(bdk.CbfClient client) async {
    final ready = ReceivePort();
    final pointer = client.uniffiClonePointer();
    try {
      await Isolate.spawn(_main, [
        pointer.address,
        Isolate(Isolate.current.controlPort),
        ready.sendPort,
      ], onExit: ready.sendPort);
    } on Object {
      bdk.CbfClient.lift(pointer).dispose();
      ready.close();
      rethrow;
    }
    try {
      final port = await ready.first;
      if (port is! SendPort) {
        throw const FormatException('CBF witness startup failed');
      }
      return CbfNativeOwner._(port);
    } finally {
      ready.close();
    }
  }

  Future<void> submit(Uint8List bytes) async {
    final reply = ReceivePort();
    commands.send(['submit', bytes, reply.sendPort]);
    try {
      if (await reply.first != true) {
        throw const FormatException('CBF submission failed');
      }
    } finally {
      reply.close();
    }
  }

  void stopping() => commands.send(['stopping']);
}

void _main(List<Object> arguments) {
  final client = bdk.CbfClient.lift(Pointer.fromAddress(arguments[0] as int));
  final owner = arguments[1] as Isolate;
  final ready = arguments[2] as SendPort;
  final commands = ReceivePort();
  final witnesses = <SendPort>{};
  var alive = true, tracked = false, pending = 0, terminated = false;
  Timer? timer;
  Timer? abandon;
  Timer? startup;

  void check() {
    final status = client.status();
    status.syncedTip?.hash.dispose();
    terminated = status.terminated;
    if (!terminated || pending != 0 || !tracked) return;
    for (final witness in witnesses) {
      witness.send(['native-terminated', commands.sendPort]);
    }
    timer?.cancel();
    abandon?.cancel();
    startup?.cancel();
    owner.removeOnExitListener(commands.sendPort);
    commands.close();
    client.dispose();
  }

  commands.listen((message) async {
    if (message == 'owner-ready') {
      startup?.cancel();
      ready.send(commands.sendPort);
      return;
    }
    if (message == 'owner-exited') {
      startup?.cancel();
      alive = false;
      try {
        client.shutdown();
      } on bdk.NodeStoppedCbfException {
        /* Still require join. */
      }
      timer ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => check(),
      );
      // Allow a registry watch already in flight to arrive before retiring.
      abandon = Timer(const Duration(seconds: 4), () {
        tracked = true;
        check();
      });
      check();
      return;
    }
    if (message is! List) return;
    switch (message.first) {
      case 'watch':
        witnesses.add(message[1] as SendPort);
        tracked = true;
        (message.last as SendPort).send(true);
        check();
      case 'untracked':
        tracked = true;
        check();
      case 'stopping':
        timer ??= Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => check(),
        );
        check();
      case 'submit':
        final reply = message[2] as SendPort;
        if (!alive || terminated) {
          reply.send(false);
          return;
        }
        pending++;
        bdk.Transaction? transaction;
        try {
          transaction = bdk.Transaction(
            transactionBytes: message[1] as Uint8List,
          );
          final result = await client.submitPackage(
            transactions: [transaction],
          );
          result.dispose();
          reply.send(true);
        } on Exception {
          reply.send(false);
        } finally {
          transaction?.dispose();
          pending--;
          check();
        }
    }
  });
  // No native run is admitted until the ordered ping below is acknowledged.
  startup = Timer(const Duration(seconds: 4), () {
    alive = false;
    tracked = true;
    ready.send(null);
    try {
      client.shutdown();
    } on bdk.NodeStoppedCbfException {
      /* Join below. */
    }
    timer ??= Timer.periodic(const Duration(milliseconds: 50), (_) => check());
    check();
  });
  owner.addOnExitListener(commands.sendPort, response: 'owner-exited');
  owner.ping(
    commands.sendPort,
    response: 'owner-ready',
    priority: Isolate.immediate,
  );
}
