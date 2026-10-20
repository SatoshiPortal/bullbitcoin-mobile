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
          payjoinDirectory: PayjoinConstants.directoryUrl,
        ),
        (null, null),
      );
      expect(attempted, PayjoinConstants.ohttpRelayUrlsBase.toSet());
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
    const retryDelay = Duration(
      seconds: PayjoinConstants.directoryMinPollSpacingSec,
    );
    // BIP 173 test vector: a valid testnet P2WPKH address.
    const receiverAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

    setUpAll(() {
      registerFallbackValue(RequestOptions(path: 'https://relay.example'));
      registerFallbackValue(Options());
      registerFallbackValue(CancelToken());
    });

    /// A receiver whose PDK session is really initialized, so a poll gets as
    /// far as the relay request; [expireAfterSec] bounds the engine-side
    /// expiry the poll enforces. With [cancelled], the PDK session is closed,
    /// so a poll replays to a state the request poll no longer serves.
    PayjoinReceiverModel initializedReceiver({
      required int expireAfterSec,
      bool cancelled = false,
    }) {
      final persister = InMemoryJsonReceiverSessionPersister();
      final initialized = ReceiverBuilder(
        address: receiverAddress,
        directory: PayjoinConstants.directoryUrl,
        ohttpKeys: _fakeOhttpKeys(),
      ).withExpiration(expirationSecs: 3600).build().save(persister: persister);
      if (cancelled) initialized.cancel().save(persister: persister);
      return PayjoinModel.receiver(
            id: 'receiver-1',
            address: receiverAddress,
            isTestnet: true,
            receiver: persister.toJson(),
            walletId: 'w1',
            pjUri:
                'bitcoin:$receiverAddress?pj=${PayjoinConstants.directoryUrl}',
            maxFeeRateSatPerVb: BigInt.from(100),
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            expireAfterSec: expireAfterSec,
          )
          as PayjoinReceiverModel;
    }

    _MockDio relayDio() {
      final dio = _MockDio();
      when(() => dio.options).thenReturn(BaseOptions());
      return dio;
    }

    Future<Response<List<int>>> Function(Invocation) throwingRelay() =>
        (invocation) async => throw DioException(
          requestOptions: RequestOptions(path: 'https://relay.example'),
          type: DioExceptionType.connectionError,
        );

    PayjoinSenderModel sender({
      required int createdAt,
      required int expireAfterSec,
    }) =>
        PayjoinModel.sender(
              uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
              isTestnet: true,
              sender: '[]',
              walletId: 'w1',
              originalPsbt: 'cHNidP8=',
              originalTxId: 'orig-txid',
              amountSat: 50000,
              createdAt: createdAt,
              expireAfterSec: expireAfterSec,
            )
            as PayjoinSenderModel;

    PayjoinSenderModel expiredSender() =>
        sender(createdAt: 0, expireAfterSec: 300);

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
        async.elapse(retryDelay * 3);

        expect(events, isEmpty);
        datasource.dispose();
        async.flushMicrotasks();
      });
    });

    test('the first poll goes out right away', () {
      fakeAsync((async) {
        final dio = relayDio();
        when(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(throwingRelay());
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: dio,
        );

        datasource.startListeningForRequest(
          initializedReceiver(expireAfterSec: 3600),
        );
        // No time passes: the request is already on its way to a relay.
        async.flushMicrotasks();
        async.elapse(Duration.zero);

        verify(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(greaterThan(0));
        datasource.dispose();
        async.flushMicrotasks();
      });
    });

    test('a failed poll is retried after the retry delay', () {
      fakeAsync((async) {
        final dio = relayDio();
        when(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(throwingRelay());
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: dio,
        );
        final relays = PayjoinConstants.ohttpRelayUrlsBase.length;

        datasource.startListeningForRequest(
          initializedReceiver(expireAfterSec: 3600),
        );
        async.elapse(Duration.zero);
        verify(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(relays);

        async.elapse(retryDelay - const Duration(milliseconds: 1));
        verifyNever(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        );

        async.elapse(const Duration(milliseconds: 1));
        verify(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(relays);
        datasource.dispose();
        async.flushMicrotasks();
      });
    });

    test('the expiry cuts a held poll short and settles the session', () {
      fakeAsync((async) {
        final dio = relayDio();
        CancelToken? seenToken;
        // A relay that holds the request until the poll's token is cancelled,
        // the way the directory holds an empty GET.
        when(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          final token = invocation.namedArguments[#cancelToken] as CancelToken;
          seenToken = token;
          throw await token.whenCancel;
        });
        // The datasource reads the fake clock, so the expiry moves with
        // async.elapse rather than with wall time.
        final start = DateTime.now();
        final datasource = PdkPayjoinDatasource(
          log: PayjoinLogger.silent,
          dio: dio,
          now: () => start.add(async.elapsed),
        );
        final events = <PayjoinModel>[];
        datasource.expiredPayjoins.listen(events.add);
        final model = initializedReceiver(expireAfterSec: 2);
        final untilExpiry = DateTime.fromMillisecondsSinceEpoch(
          model.expiresAt * 1000,
        ).difference(start);

        datasource.startListeningForRequest(model);
        async.elapse(untilExpiry - const Duration(milliseconds: 1));
        expect(events, isEmpty);
        expect(seenToken?.isCancelled, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(events, hasLength(1));
        expect(events.single.isExpired, isTrue);
        expect(seenToken?.isCancelled, isTrue);

        // Settled, and the cancelled poll asked no other relay.
        async.elapse(retryDelay * 3);
        verify(
          () => dio.post<List<int>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);
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
