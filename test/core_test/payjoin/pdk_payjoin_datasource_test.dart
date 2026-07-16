import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:payjoin/payjoin.dart';

class _MockDio extends Mock implements Dio {}

// A valid, statically-generated OHTTP key config (offline test fixture, no
// real relay behind it). Generated once via the vendored `bitcoin-ohttp`
// crate sources (`KeyConfig::new(...).encode()`) so it decodes with
// `OhttpKeys.decode` without any network access; see the PR description for
// how to regenerate it if the wire format ever changes.
final _ohttpKeysBytes = Uint8List.fromList([
  0x01,
  0x00,
  0x16,
  0x04,
  0x52,
  0x73,
  0xda,
  0xa8,
  0xf6,
  0x4c,
  0xdf,
  0x80,
  0x8f,
  0x1e,
  0x94,
  0x03,
  0x98,
  0x09,
  0xf6,
  0x47,
  0xfc,
  0x21,
  0xca,
  0x68,
  0xb2,
  0xbd,
  0x31,
  0xe7,
  0x30,
  0xa9,
  0xc5,
  0x7d,
  0xf3,
  0x68,
  0x84,
  0xb2,
  0xe7,
  0x82,
  0x6e,
  0x2f,
  0xa1,
  0xad,
  0x2b,
  0x9f,
  0x23,
  0x88,
  0x15,
  0x76,
  0x5a,
  0xa6,
  0x7b,
  0x1f,
  0x56,
  0xcc,
  0x72,
  0xc6,
  0x69,
  0x83,
  0x40,
  0x69,
  0x89,
  0x86,
  0x87,
  0x80,
  0xee,
  0x59,
  0x9b,
  0x1f,
  0x00,
  0x04,
  0x00,
  0x01,
  0x00,
  0x03,
]);

OhttpKeys _fakeOhttpKeys() => OhttpKeys.decode(bytes: _ohttpKeysBytes);

void main() {
  group('InMemoryJsonReceiverSessionPersister', () {
    test('save appends events and load returns them in order', () {
      final persister = InMemoryJsonReceiverSessionPersister();

      persister.save('a');
      persister.save('b');

      expect(persister.load(), ['a', 'b']);
      expect(persister.events, ['a', 'b']);
    });

    test('events is unmodifiable', () {
      final persister = InMemoryJsonReceiverSessionPersister();
      persister.save('a');

      expect(() => persister.events.add('b'), throwsUnsupportedError);
    });

    test('close marks the persister as closed', () {
      final persister = InMemoryJsonReceiverSessionPersister();

      expect(persister.isClosed, isFalse);
      persister.close();
      expect(persister.isClosed, isTrue);
    });

    test('toJson/fromJson round-trips the event log', () {
      final persister = InMemoryJsonReceiverSessionPersister();
      persister.save('a');
      persister.save('b');

      final restored = InMemoryJsonReceiverSessionPersister.fromJson(
        persister.toJson(),
      );

      expect(restored.load(), ['a', 'b']);
    });

    test('fromJson(null) starts with an empty event log', () {
      final persister = InMemoryJsonReceiverSessionPersister.fromJson(null);

      expect(persister.load(), isEmpty);
    });

    test('fromJson rejects malformed input as a corrupt session', () {
      // A persisted log that won't decode is unrecoverable: it must surface
      // as a typed corruption (so polling can retire the session) rather than
      // silently resetting to empty and resurrecting the session.
      expect(
        () => InMemoryJsonReceiverSessionPersister.fromJson('not valid json'),
        throwsA(isA<CorruptPayjoinSessionException>()),
      );
      expect(
        () => InMemoryJsonReceiverSessionPersister.fromJson(
          jsonEncode({'not': 'a list'}),
        ),
        throwsA(isA<CorruptPayjoinSessionException>()),
      );
      expect(
        () => InMemoryJsonReceiverSessionPersister.fromJson(
          jsonEncode([1, 2, 3]),
        ),
        throwsA(isA<CorruptPayjoinSessionException>()),
      );
    });
  });

  group('InMemoryJsonSenderSessionPersister', () {
    test('save appends events and load returns them in order', () {
      final persister = InMemoryJsonSenderSessionPersister();

      persister.save('x');
      persister.save('y');

      expect(persister.load(), ['x', 'y']);
      expect(persister.events, ['x', 'y']);
    });

    test('events is unmodifiable', () {
      final persister = InMemoryJsonSenderSessionPersister();
      persister.save('x');

      expect(() => persister.events.add('y'), throwsUnsupportedError);
    });

    test('close marks the persister as closed', () {
      final persister = InMemoryJsonSenderSessionPersister();

      expect(persister.isClosed, isFalse);
      persister.close();
      expect(persister.isClosed, isTrue);
    });

    test('toJson/fromJson round-trips the event log', () {
      final persister = InMemoryJsonSenderSessionPersister();
      persister.save('x');
      persister.save('y');

      final restored = InMemoryJsonSenderSessionPersister.fromJson(
        persister.toJson(),
      );

      expect(restored.load(), ['x', 'y']);
    });

    test('fromJson(null) starts with an empty event log', () {
      final persister = InMemoryJsonSenderSessionPersister.fromJson(null);

      expect(persister.load(), isEmpty);
    });

    test('fromJson rejects malformed input as a corrupt session', () {
      expect(
        () => InMemoryJsonSenderSessionPersister.fromJson('not valid json'),
        throwsA(isA<CorruptPayjoinSessionException>()),
      );
      expect(
        () => InMemoryJsonSenderSessionPersister.fromJson(
          jsonEncode({'not': 'a list'}),
        ),
        throwsA(isA<CorruptPayjoinSessionException>()),
      );
      expect(
        () =>
            InMemoryJsonSenderSessionPersister.fromJson(jsonEncode([1, 2, 3])),
        throwsA(isA<CorruptPayjoinSessionException>()),
      );
    });
  });

  group('PdkPayjoinDatasource.dispose', () {
    test('closes the event streams', () async {
      final datasource = PdkPayjoinDatasource(dio: Dio());

      await datasource.dispose();

      // A closed broadcast stream completes immediately with no events.
      await expectLater(datasource.requestsForReceivers, emitsDone);
      await expectLater(datasource.proposalsForSenders, emitsDone);
      await expectLater(datasource.expiredPayjoins, emitsDone);
    });

    test('is idempotent (a second dispose is a no-op)', () async {
      final datasource = PdkPayjoinDatasource(dio: Dio());

      await datasource.dispose();
      // Without the _disposed guard this would throw on re-closing a closed
      // controller.
      await expectLater(datasource.dispose(), completes);
    });
  });

  group('PdkPayjoinDatasource.stopPolling', () {
    // A session whose expiry time is long passed (createdAt: 0): the first
    // poll tick emits an expired event without any network access, which
    // makes the poll's liveness observable offline.
    PayjoinSenderModel expiredSenderModel() =>
        PayjoinModel.sender(
              uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
              isTestnet: true,
              sender: '[]',
              walletId: 'w1',
              originalPsbt: 'cHNidP8=',
              originalTxId: 'orig-txid',
              amountSat: 50000,
              createdAt: 0,
              expireAfterSec: 300,
            )
            as PayjoinSenderModel;

    test('control: without stopPolling the poll raises the expiry', () {
      fakeAsync((async) {
        final datasource = PdkPayjoinDatasource(dio: Dio());
        final events = <PayjoinModel>[];
        final sub = datasource.expiredPayjoins.listen(events.add);

        datasource.startListeningForProposal(expiredSenderModel());
        async.elapse(
          const Duration(
            seconds: PayjoinConstants.directoryPollingInterval + 1,
          ),
        );

        expect(events, hasLength(1));
        sub.cancel();
        datasource.dispose();
        async.flushMicrotasks();
      });
    });

    test('cancels the session poll so no further event ever fires — the '
        'repository calls this when a session resolves through a path the '
        'poll cannot see (fallback landed on-chain)', () {
      fakeAsync((async) {
        final datasource = PdkPayjoinDatasource(dio: Dio());
        final events = <PayjoinModel>[];
        final sub = datasource.expiredPayjoins.listen(events.add);

        final model = expiredSenderModel();
        datasource.startListeningForProposal(model);
        datasource.stopPolling(model.id);
        async.elapse(
          const Duration(
            seconds: PayjoinConstants.directoryPollingInterval * 3,
          ),
        );

        expect(events, isEmpty);
        sub.cancel();
        datasource.dispose();
        async.flushMicrotasks();
      });
    });
  });

  group('PdkPayjoinDatasource.fetchOhttpKeyAndRelay', () {
    // These exercise the multi-relay fallback loop with an injected fetcher,
    // entirely offline: PayjoinConstants.ohttpRelayUrls is shuffled on every
    // access (see lib/core/utils/constants.dart), so the loop's *order* isn't
    // asserted here, only its "try until one works, else give up" contract.

    test('returns the keys and relay for the relay that succeeds', () async {
      final keys = _fakeOhttpKeys();
      final datasource = PdkPayjoinDatasource(
        dio: Dio(),
        ohttpKeysFetcher:
            ({
              required String ohttpRelayUrl,
              required String directoryUrl,
            }) async {
              if (ohttpRelayUrl != 'https://pj.bobspacebkk.com') {
                throw Exception('relay unavailable: $ohttpRelayUrl');
              }
              return keys;
            },
      );

      final (resultKeys, resultRelay) = await datasource.fetchOhttpKeyAndRelay(
        payjoinDirectory: 'https://payjo.in',
      );

      expect(resultKeys, same(keys));
      expect(resultRelay, 'https://pj.bobspacebkk.com');
    });

    test('returns (null, null) when every relay fails', () async {
      final attemptedRelays = <String>{};
      final datasource = PdkPayjoinDatasource(
        dio: Dio(),
        ohttpKeysFetcher:
            ({
              required String ohttpRelayUrl,
              required String directoryUrl,
            }) async {
              attemptedRelays.add(ohttpRelayUrl);
              throw Exception('relay unavailable: $ohttpRelayUrl');
            },
      );

      final (resultKeys, resultRelay) = await datasource.fetchOhttpKeyAndRelay(
        payjoinDirectory: 'https://payjo.in',
      );

      expect(resultKeys, isNull);
      expect(resultRelay, isNull);
      // Every known relay must have been attempted before giving up.
      expect(attemptedRelays, {
        'https://ohttp.achow101.com',
        'https://pj.bobspacebkk.com',
        'https://ohttp.cakewallet.com',
      });
    });

    test('passes the requested directory URL through to the fetcher', () async {
      final seenDirectories = <String>{};
      final datasource = PdkPayjoinDatasource(
        dio: Dio(),
        ohttpKeysFetcher:
            ({
              required String ohttpRelayUrl,
              required String directoryUrl,
            }) async {
              seenDirectories.add(directoryUrl);
              throw Exception('relay unavailable: $ohttpRelayUrl');
            },
      );

      await datasource.fetchOhttpKeyAndRelay(
        payjoinDirectory: 'https://my-directory.example',
      );

      expect(seenDirectories, {'https://my-directory.example'});
    });
  });

  group('PdkPayjoinDatasource.postBytes', () {
    // Every OHTTP relay call (in fetchOhttpKeyAndRelay's sibling relay-loop
    // functions: postOriginalProposal, _getUncheckedOriginalPayload,
    // _getProposalPsbt, _sendPayjoinProposal) funnels through this single
    // choke point, and PayjoinLocator configures its Dio's
    // connect/send/receiveTimeout specifically so an unresponsive relay can't
    // stall a poll indefinitely. These verify the plumbing a real timeout
    // exercises: postBytes neither swallows nor transforms the failure, so
    // the relay loops' existing catch-and-try-next-relay handling applies to
    // it exactly like any other network error — without needing a live relay
    // or a signed PSBT/session fixture, which (per the receiver/sender
    // typestate walk) isn't practical to construct offline.

    setUpAll(() {
      registerFallbackValue(RequestOptions(path: 'https://relay.example.com'));
      registerFallbackValue(Options());
    });

    test('propagates a Dio receive-timeout unwrapped, so relay-loop callers '
        'can catch it and fall back to the next relay', () async {
      final dio = _MockDio();
      when(
        () => dio.post<List<int>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'https://relay.example.com'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(
        () => PdkPayjoinDatasource.postBytes(
          dio,
          'https://relay.example.com',
          Uint8List.fromList([1, 2, 3]),
          'message/ohttp-req',
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
    });

    test('returns the response bytes on success', () async {
      final dio = _MockDio();
      when(
        () => dio.post<List<int>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: 'https://relay.example.com'),
          data: [4, 5, 6],
          statusCode: 200,
        ),
      );

      final result = await PdkPayjoinDatasource.postBytes(
        dio,
        'https://relay.example.com',
        Uint8List.fromList([1, 2, 3]),
        'message/ohttp-req',
      );

      expect(result, Uint8List.fromList([4, 5, 6]));
    });
  });
}
