import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/src/domain/payjoin_regtest_profile.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';

/// Private ephemeral keys are generated into a temporary directory, never
/// embedded in fixtures, logged, or passed as command arguments.
final class RegtestTlsFixture {
  final Directory temporary;
  final String host;
  final Uint8List certificate;
  final SecurityContext serverContext;

  RegtestTlsFixture._(
    this.temporary,
    this.host,
    this.certificate,
    this.serverContext,
  );

  PayjoinRegtestProfile get profile => PayjoinRegtestProfile(
    hostProfile: fixtureHost(host),
    certificateDer: certificate,
    approvedCertificateSha256: sha256.convert(certificate).toString(),
  );

  static Future<RegtestTlsFixture> create() async {
    final temporary = await Directory.systemTemp.createTemp(
      'payjoin-private-tls-',
    );
    try {
      final permissions = await Process.run('chmod', ['700', temporary.path]);
      if (permissions.exitCode != 0) {
        throw StateError('Could not protect TLS fixture');
      }
      final host = '127.23.${(pid ~/ 250) % 250}.${pid % 250 + 1}';
      final pem = '${temporary.path}/certificate.pem';
      final key = '${temporary.path}/key.pem';
      final der = '${temporary.path}/certificate.der';
      final generated = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-sha256',
        '-nodes',
        '-days',
        '1',
        '-keyout',
        key,
        '-out',
        pem,
        '-subj',
        '/CN=regtest-transport-test',
        '-addext',
        'subjectAltName=DNS:localhost,IP:127.0.0.1,IP:$host',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
      ]);
      if (generated.exitCode != 0) {
        throw StateError('Could not create ephemeral TLS fixture');
      }
      final converted = await Process.run('openssl', [
        'x509',
        '-in',
        pem,
        '-outform',
        'DER',
        '-out',
        der,
      ]);
      if (converted.exitCode != 0) {
        throw StateError('Could not encode public test certificate');
      }
      final context = SecurityContext()
        ..useCertificateChain(pem)
        ..usePrivateKey(key);
      return RegtestTlsFixture._(
        temporary,
        host,
        await File(der).readAsBytes(),
        context,
      );
    } catch (_) {
      await temporary.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() => temporary.delete(recursive: true);
}

/// Only the CONNECT authority is logical; the private backend route is physical.
final class TestConnectRelay {
  final SecureServerSocket server;
  final String physicalHost;
  final List<int> earlyBytes;
  final bool reverse;
  final List<Socket> sockets = [];
  String? connectTarget;
  bool _closed = false;

  TestConnectRelay._(
    this.server,
    this.physicalHost,
    this.earlyBytes,
    this.reverse,
  );

  static Future<TestConnectRelay> start(
    RegtestTlsFixture fixture, {
    List<int> earlyBytes = const [],
    bool reverse = false,
  }) async {
    final relay = TestConnectRelay._(
      await SecureServerSocket.bind(
        fixture.host,
        reverse ? 8040 : 8041,
        fixture.serverContext,
      ),
      fixture.host,
      earlyBytes,
      reverse,
    );
    relay.server.listen(relay._accept);
    return relay;
  }

  void _accept(SecureSocket socket) {
    sockets.add(socket);
    _observeFixtureClose(socket);
    final header = BytesBuilder(copy: false);
    Socket? upstream;
    StreamSubscription<List<int>>? subscription;
    subscription = socket.listen(
      (chunk) async {
        final connected = upstream;
        if (connected != null) {
          connected.add(chunk);
          return;
        }
        header.add(chunk);
        final text = ascii.decode(header.toBytes(), allowInvalid: true);
        if (!text.contains('\r\n\r\n')) return;
        connectTarget = text.split('\r\n').first;
        final expected = reverse
            ? 'CONNECT 127.0.0.1:8041 HTTP/1.1'
            : 'CONNECT localhost:8040 HTTP/1.1';
        if (connectTarget != expected) {
          socket.destroy();
          return;
        }
        subscription?.pause();
        try {
          final target = await Socket.connect(
            physicalHost,
            reverse ? 8041 : 8040,
          );
          if (_closed) {
            target.destroy();
            return;
          }
          upstream = target;
          sockets.add(target);
          _observeFixtureClose(target);
          target.listen(
            socket.add,
            onDone: socket.destroy,
            onError: (Object _) => socket.destroy(),
          );
          socket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
          socket.add(earlyBytes);
          await socket.flush();
          subscription?.resume();
        } on Exception {
          socket.destroy();
        }
      },
      onDone: () => upstream?.destroy(),
      onError: (Object _) => upstream?.destroy(),
    );
  }

  Future<void> close() async {
    _closed = true;
    for (final socket in sockets) {
      socket.destroy();
    }
    await server.close();
  }
}

// The deliberately stalled peer resets an unread TLS ClientHello on teardown.
// Observe the fixture's IOSink.done error as well as its input stream error.
void _observeFixtureClose(Socket socket) {
  unawaited(
    socket.done.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (error is! SocketException && error is! TlsException) {
          Error.throwWithStackTrace(error, stack);
        }
      },
    ),
  );
}

LocalRegtestHost fixtureHost(String host) {
  final profile = RegtestHostProfile.forNetwork(NetworkEnv.regtest, host: host);
  if (profile is! LocalRegtestHost) {
    throw StateError('Regtest host unavailable');
  }
  return profile;
}
