import 'dart:async';

import 'package:bull_payjoin/src/engine/payjoin_engine_exception.dart';

import 'dart:convert';
import 'dart:io';

import 'package:bull_payjoin/src/domain/payjoin_regtest_profile.dart';
import 'package:bull_payjoin/src/engine/payjoin_regtest_transport.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/regtest_transport_fixture.dart';

void main() {
  late RegtestTlsFixture fixture;
  setUpAll(() async {
    fixture = await RegtestTlsFixture.create();
  });
  tearDownAll(() => fixture.dispose());

  for (final environment in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
    test('$environment rejects fixture trust before invalid DER parsing', () {
      final bytes = [1, 2, 3];
      final profile = PayjoinRegtestProfile(
        hostProfile: fixtureHost('127.0.0.1'),
        certificateDer: bytes,
        approvedCertificateSha256: sha256.convert(bytes).toString(),
      );
      expect(
        () =>
            PayjoinRegtestTransport(profile: profile, environment: environment),
        throwsA(isA<HttpException>()),
      );
    });
  }
  test('profile routes only the two exact logical origin pairs', () {
    final profile = fixture.profile;
    expect(profile.host, fixture.host);
    expect(profile.servers.map((s) => s.origin), [
      'https://localhost:8040',
      'https://127.0.0.1:8041',
    ]);
    for (final raw in [
      'http://localhost:8040',
      'https://localhost:8041',
      'https://127.0.0.1:8040',
      'https://foreign.invalid:8040',
      'https://user@localhost:8040',
      'https://localhost:8040/#fragment',
    ]) {
      expect(
        () => profile.requireEndpoint(Uri.parse(raw)),
        throwsFormatException,
      );
    }
    expect(profile.relaysFor(profile.servers.first), [profile.servers.last]);
    expect(profile.relaysFor(profile.servers.last), [profile.servers.first]);
  });

  for (final reverse in [false, true]) {
    for (final fragmented in [false, true]) {
      test(
        'private TLS discovery reverse=$reverse fragmented=$fragmented',
        () async {
          final directory = await HttpServer.bindSecure(
            fixture.host,
            reverse ? 8041 : 8040,
            fixture.serverContext,
          );
          final relay = await TestConnectRelay.start(fixture, reverse: reverse);
          final transport = PayjoinRegtestTransport(
            profile: fixture.profile,
            environment: NetworkEnv.regtest,
          );
          var fragments = 0;
          var stopped = false;
          // Public key config from the existing payjoin-test-utils fixture.
          final keys = base64Decode(
            'AQAWBFJz2qj2TN+Ajx6UA5gJ9kf8Icposr0x5zCpxX3zaISy54JuL6GtK58jiBV2WqZ7H1bMcsZpg0BpiYaHgO5Zmx8ABAABAAM=',
          );
          directory.listen((request) async {
            try {
              if (fragmented) {
                request.response.headers.contentLength = 1000;
                request.response.bufferOutput = false;
                while (!stopped && fragments < 1000) {
                  request.response.add([0]);
                  fragments++;
                  await request.response.flush();
                  await Future<void>.delayed(const Duration(milliseconds: 60));
                }
              } else {
                request.response.add(keys);
                await request.response.close();
              }
            } on Exception {
              /* Deadline closes the deliberately incomplete body. */
            }
          });
          final elapsed = Stopwatch()..start();
          try {
            final result = transport.fetchOhttpKeys(
              ohttpRelayUrl: fixture.profile.servers[reverse ? 0 : 1]
                  .toString(),
              directoryUrl: fixture.profile.servers[reverse ? 1 : 0].toString(),
              timeout: fragmented
                  ? const Duration(milliseconds: 250)
                  : const Duration(seconds: 2),
            );
            if (fragmented) {
              await expectLater(result, throwsA(isA<TimeoutException>()));
              expect(fragments, greaterThan(0));
              expect(elapsed.elapsedMilliseconds, lessThan(600));
            } else {
              expect(await result, isNotNull);
            }
            expect(
              relay.connectTarget,
              reverse
                  ? 'CONNECT 127.0.0.1:8041 HTTP/1.1'
                  : 'CONNECT localhost:8040 HTTP/1.1',
            );
          } finally {
            stopped = true;
            await relay.close();
            await directory.close(force: true);
            await transport.close();
          }
        },
      );
    }
  }
  test('inactive family is checked before any physical dial', () async {
    var calls = 0;
    final transport = PayjoinRegtestTransport(
      profile: fixture.profile,
      environment: NetworkEnv.regtest,
      isCurrent: () async => false,
      startConnect: (_, _) async {
        calls++;
        throw const SocketException('Unexpected dial');
      },
    );
    try {
      final task = await transport.connectPinned(fixture.profile.servers.first);
      await expectLater(
        task.socket,
        throwsA(isA<PayjoinRuntimeInactiveException>()),
      );
      expect(calls, 0);
    } finally {
      await transport.close();
    }
  });

  test('family change after TCP prevents the next TLS step', () async {
    var active = true;
    var tlsCalls = 0;
    final server = await ServerSocket.bind(fixture.host, 8040);
    final closed = Completer<void>();
    final peers = <Socket>[];
    server.listen((peer) {
      peers.add(peer);
      peer.listen(
        (_) {},
        onDone: () {
          if (!closed.isCompleted) closed.complete();
        },
      );
    });
    final transport = PayjoinRegtestTransport(
      profile: fixture.profile,
      environment: NetworkEnv.regtest,
      isCurrent: () async => active,
      startConnect: (host, port) async {
        final task = await Socket.startConnect(host, port);
        return ConnectionTask.fromSocket(
          task.socket.then((socket) {
            active = false;
            return socket;
          }),
          task.cancel,
        );
      },
      secure: (_, _, _) async {
        tlsCalls++;
        throw const HandshakeException('Unexpected TLS');
      },
    );
    try {
      final task = await transport.connectPinned(fixture.profile.servers.first);
      await expectLater(
        task.socket,
        throwsA(isA<PayjoinRuntimeInactiveException>()),
      );
      expect(tlsCalls, 0);
      await closed.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TestFailure('Private TCP peer not closed'),
      );
    } finally {
      for (final peer in peers) {
        peer.destroy();
      }
      await server.close();
      await transport.close();
    }
  });

  test('close joins actual inner TLS beyond its discovery deadline', () async {
    final server = await ServerSocket.bind(fixture.host, 8040);
    final peers = <Socket>[];
    server.listen(peers.add);
    final relay = await TestConnectRelay.start(fixture);
    final started = Completer<void>();
    var calls = 0;
    final transport = PayjoinRegtestTransport(
      profile: fixture.profile,
      environment: NetworkEnv.regtest,
      secure: (socket, host, context) {
        final future = SecureSocket.secure(
          socket,
          host: host,
          context: context,
        );
        if (++calls == 2) started.complete();
        return future;
      },
    );
    Future<void>? closing;
    try {
      final failed = expectLater(
        transport.fetchOhttpKeys(
          ohttpRelayUrl: fixture.profile.servers.last.toString(),
          directoryUrl: fixture.profile.servers.first.toString(),
          timeout: const Duration(milliseconds: 250),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await started.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TestFailure('Private inner TLS not started'),
      );
      var closed = false;
      closing = transport.close().then((_) {
        closed = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(closed, isFalse);
      for (final peer in peers) {
        peer.destroy();
      }
      await failed;
      await closing;
    } finally {
      for (final peer in peers) {
        peer.destroy();
      }
      await relay.close();
      await server.close();
      await closing;
      await transport.close();
    }
  });
}
