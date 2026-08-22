import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:payjoin/payjoin.dart';
import 'package:test/test.dart';

class _MockDio extends Mock implements Dio {}

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
  group('JSON session persisters', () {
    test('receiver events round-trip and are exposed read-only', () {
      final persister = InMemoryJsonReceiverSessionPersister()
        ..save('a')
        ..save('b');

      expect(persister.load(), ['a', 'b']);
      expect(() => persister.events.add('c'), throwsUnsupportedError);
      expect(
        InMemoryJsonReceiverSessionPersister.fromJson(
          persister.toJson(),
        ).load(),
        ['a', 'b'],
      );
    });

    test('sender events round-trip and malformed input becomes empty', () {
      final persister = InMemoryJsonSenderSessionPersister()
        ..save('a')
        ..save('b');

      expect(
        InMemoryJsonSenderSessionPersister.fromJson(persister.toJson()).load(),
        ['a', 'b'],
      );
      expect(
        InMemoryJsonSenderSessionPersister.fromJson('not-json').load(),
        isEmpty,
      );
      expect(
        InMemoryJsonSenderSessionPersister.fromJson(jsonEncode([1, 2])).load(),
        isEmpty,
      );
    });
  });

  group('fetchOhttpKeyAndRelay', () {
    test(
      'returns the first successful relay and requested directory',
      () async {
        final keys = _fakeOhttpKeys();
        final seenDirectories = <String>{};
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: Dio(),
          ohttpKeysFetcher:
              ({required ohttpRelayUrl, required directoryUrl}) async {
                seenDirectories.add(directoryUrl);
                if (ohttpRelayUrl != 'https://pj.bobspacebkk.com') {
                  throw StateError('relay unavailable');
                }
                return keys;
              },
        );

        final (resultKeys, relay) = await datasource.fetchOhttpKeyAndRelay(
          payjoinDirectory: 'https://directory.example',
        );

        expect(resultKeys, same(keys));
        expect(relay, 'https://pj.bobspacebkk.com');
        expect(seenDirectories, {'https://directory.example'});
        await datasource.dispose();
      },
    );

    test('tries every relay before returning unavailable', () async {
      final attempted = <String>{};
      final datasource = PdkPayjoinDatasource(
        log: PayjoinLogger.silent,
        dio: Dio(),
        ohttpKeysFetcher:
            ({required ohttpRelayUrl, required directoryUrl}) async {
              attempted.add(ohttpRelayUrl);
              throw StateError('relay unavailable');
            },
      );

      expect(
        await datasource.fetchOhttpKeyAndRelay(
          payjoinDirectory: PayjoinConstants.publicDirectoryUrl,
        ),
        (null, null),
      );
      expect(attempted, PayjoinConstants.ohttpRelayUrlsBase.toSet());
      await datasource.dispose();
    });

    test(
      'NEVER pairs the Bull Bitcoin relay with the Bull Bitcoin directory',
      () async {
        final attempted = <String>{};
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: Dio(),
          ohttpKeysFetcher:
              ({required ohttpRelayUrl, required directoryUrl}) async {
                attempted.add(ohttpRelayUrl);
                throw StateError('relay unavailable');
              },
        );

        expect(
          await datasource.fetchOhttpKeyAndRelay(
            payjoinDirectory: PayjoinConstants.bullBitcoinDirectoryUrl,
          ),
          (null, null),
        );
        expect(
          attempted,
          PayjoinConstants.ohttpRelayUrlsBase.toSet()
            ..remove(PayjoinConstants.bullBitcoinOhttpRelayUrl),
        );
        expect(
          attempted,
          isNot(contains(PayjoinConstants.bullBitcoinOhttpRelayUrl)),
        );
        await datasource.dispose();
      },
    );
  });

  group('ohttpRelayUrlsFor', () {
    test('excludes the Bull Bitcoin relay for the Bull Bitcoin directory', () {
      final relays = PayjoinConstants.ohttpRelayUrlsFor(
        PayjoinConstants.bullBitcoinDirectoryUrl,
      );
      expect(
        relays,
        isNot(contains(PayjoinConstants.bullBitcoinOhttpRelayUrl)),
      );
      expect(
        relays.toSet(),
        PayjoinConstants.ohttpRelayUrlsBase.toSet()
          ..remove(PayjoinConstants.bullBitcoinOhttpRelayUrl),
      );
    });

    test('allows every relay for the public directory', () {
      expect(
        PayjoinConstants.ohttpRelayUrlsFor(
          PayjoinConstants.publicDirectoryUrl,
        ).toSet(),
        PayjoinConstants.ohttpRelayUrlsBase.toSet(),
      );
    });

    test('fails closed when the directory is unknown or unparseable', () {
      for (final directory in [null, '', 'not a url']) {
        expect(
          PayjoinConstants.ohttpRelayUrlsFor(directory),
          isNot(contains(PayjoinConstants.bullBitcoinOhttpRelayUrl)),
          reason: 'directory: $directory',
        );
      }
    });

    test('applies the rule from a BIP21 pj endpoint, case-insensitively', () {
      final bullBitcoinBip21 =
          'bitcoin:BC1QEXAMPLE?amount=0.001'
          '&pj=HTTPS://PAYJOIN.BULLBITCOIN.COM/ABC123%23OH1QYPM5'
          '&pjos=0';
      expect(
        PayjoinConstants.ohttpRelayUrlsForBip21(bullBitcoinBip21),
        isNot(contains(PayjoinConstants.bullBitcoinOhttpRelayUrl)),
      );

      final publicBip21 =
          'bitcoin:bc1qexample?amount=0.001&pj=https://payjo.in/abc123';
      expect(
        PayjoinConstants.ohttpRelayUrlsForBip21(publicBip21).toSet(),
        PayjoinConstants.ohttpRelayUrlsBase.toSet(),
      );

      // No pj endpoint at all: fail closed.
      expect(
        PayjoinConstants.ohttpRelayUrlsForBip21('bitcoin:bc1qexample'),
        isNot(contains(PayjoinConstants.bullBitcoinOhttpRelayUrl)),
      );
    });
  });

  group('fetchOhttpKeyRelayAndDirectory', () {
    test('prefers the Bull Bitcoin directory when reachable', () async {
      final keys = _fakeOhttpKeys();
      final datasource = PdkPayjoinDatasource(
        log: PayjoinLogger.silent,
        dio: Dio(),
        ohttpKeysFetcher:
            ({required ohttpRelayUrl, required directoryUrl}) async => keys,
      );

      final (resultKeys, relay, directory) = await datasource
          .fetchOhttpKeyRelayAndDirectory();

      expect(resultKeys, same(keys));
      expect(directory, PayjoinConstants.bullBitcoinDirectoryUrl);
      expect(relay, isNot(PayjoinConstants.bullBitcoinOhttpRelayUrl));
      await datasource.dispose();
    });

    test(
      'falls back to the public directory when Bull Bitcoin is down',
      () async {
        final keys = _fakeOhttpKeys();
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: Dio(),
          ohttpKeysFetcher:
              ({required ohttpRelayUrl, required directoryUrl}) async {
                if (directoryUrl == PayjoinConstants.bullBitcoinDirectoryUrl) {
                  throw StateError('directory unavailable');
                }
                return keys;
              },
        );

        final (resultKeys, relay, directory) = await datasource
            .fetchOhttpKeyRelayAndDirectory();

        expect(resultKeys, same(keys));
        expect(directory, PayjoinConstants.publicDirectoryUrl);
        expect(relay, isNotNull);
        await datasource.dispose();
      },
    );

    test('returns nulls when every directory is down', () async {
      final datasource = PdkPayjoinDatasource(
        log: PayjoinLogger.silent,
        dio: Dio(),
        ohttpKeysFetcher:
            ({required ohttpRelayUrl, required directoryUrl}) async {
              throw StateError('unavailable');
            },
      );

      expect(await datasource.fetchOhttpKeyRelayAndDirectory(), (
        null,
        null,
        null,
      ));
      await datasource.dispose();
    });
  });

  group('postBytes', () {
    setUpAll(() {
      registerFallbackValue(RequestOptions(path: 'https://relay.example'));
      registerFallbackValue(Options());
    });

    test('propagates Dio timeouts for relay fallback', () async {
      final dio = _MockDio();
      when(
        () => dio.post<List<int>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'https://relay.example'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(
        () => PdkPayjoinDatasource.postBytes(
          dio,
          'https://relay.example',
          Uint8List.fromList([1]),
          'message/ohttp-req',
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
    });

    test('returns response bytes', () async {
      final dio = _MockDio();
      when(
        () => dio.post<List<int>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: 'https://relay.example'),
          data: [4, 5, 6],
        ),
      );

      expect(
        await PdkPayjoinDatasource.postBytes(
          dio,
          'https://relay.example',
          Uint8List.fromList([1]),
          'message/ohttp-req',
        ),
        Uint8List.fromList([4, 5, 6]),
      );
    });
  });

  group('polling lifecycle', () {
    PayjoinSenderModel expiredSender() =>
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

    test('stopPolling prevents a pending expiry event', () {
      fakeAsync((async) {
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: Dio(),
        );
        final events = <PayjoinModel>[];
        datasource.expiredPayjoins.listen(events.add);
        final model = expiredSender();

        datasource.startListeningForProposal(model);
        datasource.stopPolling(model.id);
        async.elapse(
          const Duration(
            seconds: PayjoinConstants.directoryPollingInterval * 3,
          ),
        );

        expect(events, isEmpty);
        datasource.dispose();
        async.flushMicrotasks();
      });
    });

    test('dispose closes streams and is idempotent', () async {
      final datasource = PdkPayjoinDatasource(
        log: PayjoinLogger.silent,
        dio: Dio(),
      );

      await datasource.dispose();

      await expectLater(datasource.requestsForReceivers, emitsDone);
      await expectLater(datasource.proposalsForSenders, emitsDone);
      await expectLater(datasource.expiredPayjoins, emitsDone);
      await expectLater(datasource.dispose(), completes);
    });
  });
}
