import 'dart:convert';

import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinLogCode, PayjoinLogEvent, PayjoinLogLevel, PayjoinLogPort;
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:payjoin/payjoin.dart' as pdk;
import 'package:test/test.dart';

// Public OHTTP key configuration from payjoin-test-utils.
const _ohttpKeys =
    'AQAWBFJz2qj2TN+Ajx6UA5gJ9kf8Icposr0x5zCpxX3zaISy54JuL6GtK58jiBV2WqZ7H1bMcsZpg0BpiYaHgO5Zmx8ABAABAAM=';

final class _CaptureLogPort implements PayjoinLogPort {
  final events = <PayjoinLogEvent>[];

  @override
  void write(PayjoinLogEvent event) => events.add(event);
}

void main() {
  test('an expired receiver session ends without blaming any server', () async {
    const address = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
    final persister = InMemoryJsonReceiverSessionPersister();
    // The payjoin session expires after one second, while the local model
    // still believes it is valid, so the local expiry backstop stays silent.
    final initialized = pdk.ReceiverBuilder(
      address: address,
      directory: PayjoinConstants.serverUrls.first.toString(),
      ohttpKeys: pdk.OhttpKeys.decode(bytes: base64Decode(_ohttpKeys)),
    ).withExpiration(expirationSecs: 1).build().save(persister: persister);
    final model =
        PayjoinModel.receiver(
              id: '0123456789abcdef',
              address: address,
              isTestnet: true,
              receiver: persister.toJson(),
              walletId: 'w1',
              pjUri: initialized.pjUri().asString(),
              maxFeeRateSatPerVb: BigInt.from(10),
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              expireAfterSec: 600,
            )
            as PayjoinReceiverModel;
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    fakeAsync((clock) {
      final requests = <String>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options.uri.host);
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'no network in tests',
                ),
              );
            },
          ),
        );
      final port = _CaptureLogPort();
      final datasource = PdkPayjoinDatasource(
        dio: dio,
        log: PayjoinLogger(port),
      );
      final expired = <PayjoinModel>[];
      datasource.expiredPayjoins.listen(expired.add);

      datasource.startListeningForRequest(model);
      clock.elapse(
        const Duration(seconds: PayjoinConstants.directoryPollingInterval),
      );

      expect(expired.map((payjoin) => payjoin.id), [model.id]);
      expect(
        requests,
        isEmpty,
        reason: 'nothing is sent for an expired session',
      );
      expect(
        port.events.where((event) => event.level == PayjoinLogLevel.warning),
        isEmpty,
      );
      expect(
        port.events.map((event) => event.code),
        isNot(contains(PayjoinLogCode.directoryUnreachable)),
      );
      datasource.dispose();
      clock.flushMicrotasks();
      dio.close(force: true);
    });
  });
}
