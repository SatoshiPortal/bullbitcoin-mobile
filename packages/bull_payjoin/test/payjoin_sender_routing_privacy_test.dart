import 'dart:convert';
import 'dart:math';

import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinLogCode, PayjoinLogEvent, PayjoinLogPort;
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:payjoin/payjoin.dart' as pdk;
import 'package:test/test.dart';

// Public ORIGINAL_PSBT and OHTTP key fixtures from payjoin-test-utils.
const _originalPsbt =
    'cHNidP8BAHMCAAAAAY8nutGgJdyYGXWiBEb45Hoe9lWGbkxh/6bNiOJdCDuDAAAAAAD+////AtyVuAUAAAAAF6kUHehJ8GnSdBUOOv6ujXLrWmsJRDCHgIQeAAAAAAAXqRR3QJbbz0hnQ8IvQ0fptGn+votneofTAAAAAAEBIKgb1wUAAAAAF6kU3k4ekGHKWRNbA1rV5tR5kEVDVNCHAQcXFgAUx4pFclNVgo1WWAdN1SYNX8tphTABCGsCRzBEAiB8Q+A6dep+Rz92vhy26lT0AjZn4PRLi8Bf9qoB/CMk0wIgP/Rj2PWZ3gEjUkTlhDRNAQ0gXwTO7t9n+V14pZ6oljUBIQMVmsAaoNWHVMS02LfTSe0e388LNitPa1UQZyOihY+FFgABABYAFEb2Giu6c4KO5YW0pfw3lGp9jMUUAAA=';
const _ohttpKeys =
    'AQAWBFJz2qj2TN+Ajx6UA5gJ9kf8Icposr0x5zCpxX3zaISy54JuL6GtK58jiBV2WqZ7H1bMcsZpg0BpiYaHgO5Zmx8ABAABAAM=';
const _expiredBip21 =
    'bitcoin:2N47mmrWXsNBvQR6k78hWJoTji57zXwNcU7?pjos=0&pj=HTTPS://PJ.BULLBITCOIN.COM/TXJCGKTKXLUUZ%23EX1WKV8CEC-OH1QYPM59NK2LXXS4890SUAXXYT25Z2VAPHP0X7YEYCJXGWAG6UG9ZU6NQ-RK1Q0DJS3VVDXWQQTLQ8022QGXSX7ML9PHZ6EDSF6AKEWQG758JPS2EV';

final class _CaptureLogPort implements PayjoinLogPort {
  final events = <PayjoinLogEvent>[];

  @override
  void write(PayjoinLogEvent event) => events.add(event);
}

void main() {
  test('an expired URI does not mark a server as unreachable', () async {
    final port = _CaptureLogPort();
    var requests = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'unexpected request',
            ),
          );
        },
      ),
    );
    final datasource = PdkPayjoinDatasource(dio: dio, log: PayjoinLogger(port));
    try {
      await expectLater(
        datasource.createSender(
          walletId: 'fixture-wallet',
          isTestnet: true,
          bip21: _expiredBip21,
          originalPsbt: _originalPsbt,
          amountSat: 10000,
          networkFeesSatPerVb: 4,
          persistBeforePost: (_) async {},
        ),
        throwsA(isA<SendCreationException>()),
      );
      expect(requests, 0);
      expect(
        port.events.where(
          (event) => {
            PayjoinLogCode.relayUnreachable,
            PayjoinLogCode.directoryUnreachable,
            PayjoinLogCode.relayFailure,
            PayjoinLogCode.serverRecovered,
          }.contains(event.code),
        ),
        isEmpty,
        reason: 'local validation must not change server availability',
      );
    } finally {
      await datasource.dispose();
      dio.close(force: true);
    }
  });

  for (final directory in PayjoinConstants.serverUrls) {
    test('sender retries only other servers for ${directory.host}', () async {
      await _expectSenderRoutes(
        directory: directory,
        servers: PayjoinConstants.serverUrls,
        expectedRelays: PayjoinConstants.serverUrls
            .where((server) => server != directory)
            .toList(),
      );
    });
  }

  test(
    'sender excludes another subdomain of its directory on every retry',
    () async {
      final directory = Uri.https('directory.example.com');
      final sameDomain = Uri.https('relay.example.com');
      final independent = Uri.https('relay.example.org');
      await _expectSenderRoutes(
        directory: directory,
        servers: [directory, sameDomain, independent],
        expectedRelays: [independent],
      );
    },
  );

  test(
    'sender makes no request when all relays share the directory domain',
    () async {
      await _expectSenderRoutes(
        directory: Uri.https('directory.example.com'),
        servers: [Uri.https('relay.example.com')],
        expectedRelays: [],
      );
    },
  );

  test(
    'sender still reaches a directory outside the configured pool',
    () async {
      await _expectSenderRoutes(
        directory: Uri.https('payjo.in'),
        servers: PayjoinConstants.serverUrls,
        expectedRelays: PayjoinConstants.serverUrls,
      );
    },
  );
}

Future<void> _expectSenderRoutes({
  required Uri directory,
  required List<Uri> servers,
  required List<Uri> expectedRelays,
}) async {
  final receiver = pdk.ReceiverBuilder(
    address: '2N47mmrWXsNBvQR6k78hWJoTji57zXwNcU7',
    directory: directory.toString(),
    ohttpKeys: pdk.OhttpKeys.decode(bytes: base64Decode(_ohttpKeys)),
  ).build().save(persister: InMemoryJsonReceiverSessionPersister());

  for (var seed = 0; seed < 3; seed++) {
    final attempts = <String>[];
    var persisted = false;
    final dio = Dio();
    // Reject before the HTTP adapter: fixture transactions never leave the test.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(
            persisted,
            isTrue,
            reason: 'persist before exposing the original',
          );
          attempts.add(options.uri.host);
          handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'simulate an unavailable relay',
            ),
          );
        },
      ),
    );
    final datasource = PdkPayjoinDatasource(
      dio: dio,
      log: PayjoinLogger.silent,
      servers: servers,
      random: Random(seed),
    );
    try {
      await expectLater(
        datasource.createSender(
          walletId: 'fixture-wallet',
          isTestnet: true,
          bip21: receiver.pjUri().asString(),
          originalPsbt: _originalPsbt,
          amountSat: 10000,
          networkFeesSatPerVb: 4,
          persistBeforePost: (_) async => persisted = true,
        ),
        throwsA(isA<SendCreationException>()),
      );
      expect(persisted, isTrue);
      expect(
        attempts,
        unorderedEquals(expectedRelays.map((relay) => relay.host)),
        reason: 'seed=$seed, directory=${directory.host}',
      );
    } finally {
      await datasource.dispose();
      dio.close(force: true);
    }
  }
}
