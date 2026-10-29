import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

/// The named port belongs to a witness, not the isolate owning native nodes.
/// Missing native acknowledgements keep dead owners quarantined, including DNS stalls.
final class CbfOwnerRegistration {
  final SendPort _witness;
  final SendPort _identity;
  final ReceivePort _stopRequests;
  final ReceivePort _identityPort;

  CbfOwnerRegistration._(
    this._witness,
    this._identity,
    this._stopRequests,
    this._identityPort,
  );

  static Future<CbfOwnerRegistration?> acquire(
    String name, {
    required Future<bool> Function() onStop,
  }) async {
    final ready = ReceivePort(),
        requests = ReceivePort(),
        identity = ReceivePort();
    await Isolate.spawn(_witnessMain, [
      name,
      Isolate(Isolate.current.controlPort),
      ready.sendPort,
      requests.sendPort,
      identity.sendPort,
    ]);
    final witness = await ready.first;
    ready.close();
    if (witness is! SendPort) {
      requests.close();
      identity.close();
      return null;
    }
    final owner = CbfOwnerRegistration._(
      witness,
      identity.sendPort,
      requests,
      identity,
    );
    requests.listen((message) async {
      if (message is! SendPort) return;
      try {
        final stopped = await onStop();
        if (stopped) await owner.nativeStopped();
        message.send(stopped);
      } on Exception {
        message.send(false);
      }
    });
    return owner;
  }

  /// Arms admission with the lease bound; registered native guards must also join.
  Future<bool> armNative({Duration? nativeTerminationBoundAfterOwnerExit}) =>
      _request(_witness, [
        'arm',
        _identity,
        nativeTerminationBoundAfterOwnerExit,
      ]);

  Future<bool> trackNativeNode(SendPort monitor) =>
      _request(_witness, ['track', _identity, monitor]);

  Future<bool> nativeStopped() => _request(_witness, ['stopped', _identity]);

  Future<bool> release() async {
    final released = await _request(_witness, ['release', _identity]);
    if (released) {
      _stopRequests.close();
      _identityPort.close();
    }
    return released;
  }

  static Future<bool> stop(String name) async {
    final port = IsolateNameServer.lookupPortByName(name);
    return port == null || await _request(port, ['stop']);
  }
}

Future<bool> _request(SendPort port, List<Object?> command) async {
  final reply = ReceivePort();
  port.send([...command, reply.sendPort]);
  try {
    return await reply.first.timeout(const Duration(seconds: 4)) == true;
  } on TimeoutException {
    return false;
  } finally {
    reply.close();
  }
}

void _witnessMain(List<Object?> arguments) {
  final name = arguments[0] as String;
  final owner = arguments[1] as Isolate;
  final ready = arguments[2] as SendPort;
  final stopRequests = arguments[3] as SendPort;
  final identity = arguments[4] as SendPort;
  final commands = ReceivePort();
  var registered = false, alive = true, armed = false;
  Duration? nativeTerminationBound;
  Timer? lease;
  var boundElapsed = false;
  final nativeGuards = <SendPort>{};
  Timer? startup;

  void release() {
    if (registered &&
        IsolateNameServer.lookupPortByName(name) == commands.sendPort) {
      IsolateNameServer.removePortNameMapping(name);
    }
    lease?.cancel();
    startup?.cancel();
    owner.removeOnExitListener(commands.sendPort);
    commands.close();
  }

  void recover() {
    if (!alive && boundElapsed && nativeGuards.isEmpty) release();
  }

  commands.listen((message) async {
    if (message is List && message.first == 'native-terminated') {
      nativeGuards.remove(message[1]);
      recover();
      return;
    }
    if (message == 'owner-ready') {
      startup?.cancel();
      registered = IsolateNameServer.registerPortWithName(
        commands.sendPort,
        name,
      );
      ready.send(registered ? commands.sendPort : null);
      if (!registered) release();
      return;
    }
    if (message == 'owner-exited') {
      alive = false;
      if (!registered) ready.send(null);
      if (!armed) {
        release();
      } else if (nativeTerminationBound case final bound?) {
        // Measured from the VM's confirmed exit, never a wall-clock timestamp
        // or a Dart heartbeat timeout. No renewal can follow this exit.
        lease = Timer(bound, () {
          boundElapsed = true;
          recover();
        });
      }
      return;
    }
    if (message is! List || message.last is! SendPort) return;
    final reply = message.last as SendPort;
    if (message.first == 'stop') {
      if (alive) {
        stopRequests.send(reply);
      } else {
        reply.send(!armed);
      }
      return;
    }
    if (message.length < 3 || message[1] != identity) {
      reply.send(false);
      return;
    }
    switch (message.first) {
      case 'arm':
        if (!alive) {
          reply.send(false);
          return;
        }
        armed = true;
        nativeTerminationBound = message[2] as Duration?;
        reply.send(true);
      case 'track':
        if (!alive || !armed) {
          reply.send(false);
          return;
        }
        final monitor = message[2] as SendPort;
        nativeGuards.add(monitor);
        // Admitted native nodes retain their guard until actual join; elapsed
        // time cannot certify a runtime waiting for the OS DNS resolver.
        final watched = await _request(monitor, ['watch', commands.sendPort]);
        if (!watched) {
          // Native run was never admitted by this failed handshake.
          nativeGuards.remove(monitor);
          recover();
        }
        reply.send(watched);
      case 'stopped':
        nativeGuards.clear();
        armed = false;
        reply.send(true);
        if (!alive) release();
      case 'release':
        reply.send(!armed);
        if (!armed) release();
    }
  });
  // An owner can die before addOnExitListener is installed. In that case the
  // VM sends neither exit nor ping; no registration or native admission exists.
  startup = Timer(const Duration(seconds: 4), () {
    ready.send(null);
    release();
  });
  owner.addOnExitListener(commands.sendPort, response: 'owner-exited');
  // VM control messages from this sender are ordered: the ping acknowledges
  // installation of the exit listener before this registration admits work.
  owner.ping(
    commands.sendPort,
    response: 'owner-ready',
    priority: Isolate.immediate,
  );
}
