import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:math';
import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinLogCode, PayjoinLogEvent, PayjoinLogLevel, PayjoinLogPort;
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/payjoin_servers.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:payjoin/payjoin.dart';
import 'package:test/test.dart';

class _MockDio extends Mock implements Dio {}

final class _CaptureLogPort implements PayjoinLogPort {
  final events = <PayjoinLogEvent>[];

  @override
  void write(PayjoinLogEvent event) => events.add(event);

  Iterable<PayjoinLogEvent> at(PayjoinLogLevel level) =>
      events.where((event) => event.level == level);
}

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

  group('fetchDirectoryKeys', () {
    test(
      'moves to another relay off the directory host when one fails',
      () async {
        const directory = 'https://payjoin.lab.vinteum.org';
        const workingRelay = 'https://pj.bobspacebkk.com';
        final keys = _fakeOhttpKeys();
        final attempts = <(String, String)>[];
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: Dio(),
          random: Random(2),
          ohttpKeysFetcher:
              ({
                required ohttpRelayUrl,
                required directoryUrl,
                required timeout,
              }) async {
                attempts.add((ohttpRelayUrl, directoryUrl));
                if (directoryUrl != directory ||
                    ohttpRelayUrl != workingRelay) {
                  throw StateError('unavailable');
                }
                return keys;
              },
        );

        final result = await datasource.fetchDirectoryKeys();

        expect(result?.keys, same(keys));
        expect(result?.directory, directory);
        expect(attempts.last, (workingRelay, directory));
        for (final (relay, directory) in attempts) {
          expect(relay, isNot(directory));
        }
        await datasource.dispose();
      },
    );

    test(
      'tries every relay outside each directory domain, then gives up',
      () async {
        final attempts = <(String, String)>[];
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: Dio(),
          ohttpKeysFetcher:
              ({
                required ohttpRelayUrl,
                required directoryUrl,
                required timeout,
              }) async {
                attempts.add((ohttpRelayUrl, directoryUrl));
                throw StateError('unavailable');
              },
        );

        expect(await datasource.fetchDirectoryKeys(), isNull);
        final urls = PayjoinConstants.serverUrls.map((url) => url.toString());
        expect(attempts.toSet(), {
          for (final directory in urls)
            for (final relay in urls)
              if (relay != directory) (relay, directory),
        });
        expect(attempts, hasLength(urls.length * (urls.length - 1)));
        await datasource.dispose();
      },
    );

    test(
      'warns once about a relay that failed, then logs its recovery',
      () async {
        const bull = 'https://pj.bullbitcoin.com';
        var bullUp = false;
        final port = _CaptureLogPort();
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger(port),
          dio: Dio(),
          random: Random(4),
          ohttpKeysFetcher:
              ({
                required ohttpRelayUrl,
                required directoryUrl,
                required timeout,
              }) async {
                if (ohttpRelayUrl == bull && !bullUp) {
                  throw StateError('relay down');
                }
                return _fakeOhttpKeys();
              },
        );

        for (var i = 0; i < 20; i++) {
          await datasource.fetchDirectoryKeys();
        }
        final warning = port.at(PayjoinLogLevel.warning).single;
        expect(warning.code, PayjoinLogCode.relayUnreachable);
        expect(warning.server?.host, 'pj.bullbitcoin.com');
        expect(
          port
              .at(PayjoinLogLevel.info)
              .map((event) => event.server?.host)
              .toSet(),
          {'pj.bullbitcoin.com'},
          reason: 'repeats stay out of the persisted log',
        );

        bullUp = true;
        for (var i = 0; i < 20; i++) {
          await datasource.fetchDirectoryKeys();
        }
        final recovered = port.at(PayjoinLogLevel.fine).single;
        expect(recovered.code, PayjoinLogCode.serverRecovered);
        expect(recovered.server?.host, 'pj.bullbitcoin.com');
        expect(port.at(PayjoinLogLevel.warning), hasLength(1));
        await datasource.dispose();
      },
    );

    test(
      'blames the directory, not its relays, when none reaches it',
      () async {
        final port = _CaptureLogPort();
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger(port),
          dio: Dio(),
          random: Random(5),
          ohttpKeysFetcher:
              ({
                required ohttpRelayUrl,
                required directoryUrl,
                required timeout,
              }) async {
                if (directoryUrl == 'https://pj.bullbitcoin.com') {
                  throw StateError('directory down');
                }
                return _fakeOhttpKeys();
              },
        );

        for (var i = 0; i < 20; i++) {
          expect(await datasource.fetchDirectoryKeys(), isNotNull);
        }
        final warning = port.at(PayjoinLogLevel.warning).single;
        expect(warning.code, PayjoinLogCode.directoryUnreachable);
        expect(warning.server?.host, 'pj.bullbitcoin.com');
        expect(
          port.events.where(
            (event) => event.code == PayjoinLogCode.relayUnreachable,
          ),
          isEmpty,
        );
        await datasource.dispose();
      },
    );
  });

  group('relays reach a directory only from another domain', () {
    final sameEntity = core.Uri.https('ohttp.example.com');
    final directory = core.Uri.https('dir.example.com');
    final otherEntity = core.Uri.https('relay.example.org');
    final servers = [sameEntity, directory, otherEntity];

    setUpAll(() => registerFallbackValue(Options()));

    test('when fetching the OHTTP keys of a directory', () async {
      final attempts = <(String, String)>[];
      final datasource = PdkPayjoinDatasource(
        log: PayjoinLogger.silent,
        dio: Dio(),
        servers: servers,
        ohttpKeysFetcher:
            ({
              required ohttpRelayUrl,
              required directoryUrl,
              required timeout,
            }) async {
              attempts.add((ohttpRelayUrl, directoryUrl));
              throw StateError('unavailable');
            },
      );

      expect(await datasource.fetchDirectoryKeys(), isNull);
      expect(attempts.where((attempt) => attempt.$2 == directory.toString()), [
        (otherEntity.toString(), directory.toString()),
      ]);
      for (final (relay, dir) in attempts) {
        expect(
          payjoinDomainOf(core.Uri.parse(relay)),
          isNot(payjoinDomainOf(core.Uri.parse(dir))),
        );
      }
      await datasource.dispose();
    });

    test('when a receiver session polls its directory', () {
      fakeAsync((async) {
        final relayHosts = <String>[];
        final dio = _MockDio();
        when(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          relayHosts.add(core.Uri.parse(url).host);
          throw StateError('relay unavailable');
        });
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: dio,
          servers: servers,
          ohttpKeysFetcher:
              ({
                required ohttpRelayUrl,
                required directoryUrl,
                required timeout,
              }) async {
                if (directoryUrl != directory.toString()) {
                  throw StateError('unavailable');
                }
                return _fakeOhttpKeys();
              },
        );

        PayjoinReceiverModel? receiver;
        datasource
            .createReceiver(
              walletId: 'w1',
              address: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
              isTestnet: true,
              maxFeeRateSatPerVb: BigInt.from(10),
              expireAfterSec: 600,
            )
            .then((model) => receiver = model);
        async.flushMicrotasks();
        expect(payjoinDirectoryOf(receiver?.pjUri ?? '')?.host, directory.host);

        async.elapse(
          const Duration(seconds: PayjoinConstants.directoryPollingInterval),
        );

        expect(relayHosts, [otherEntity.host]);
        datasource.dispose();
        async.flushMicrotasks();
      });
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
