import 'package:electrum/testing.dart';

import 'dart:io';

import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/fees/data/regtest_fees_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// A loopback URL nothing listens on.
Future<String> _closedUrl() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return 'tcp://127.0.0.1:$port';
}

// Sync reports these failures as values; the app's owners must turn them into
// what their callers expect, never into an Error.
void main() {
  test('regtest fees from an unreachable server throw an Exception, so the '
      'next server is tried', () async {
    final connection = ElectrumConnection(
      url: await _closedUrl(),
      retry: 0,
      timeout: 2,
      stopGap: 20,
      validateDomain: false,
      isCustom: true,
    );
    await expectLater(
      const RegtestFeesDatasource().fetch(connection),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'the Bitcoin probe of an unreachable server reports it offline',
    () async {
      final adapter = ServerStatusAdapter(const ElectrumSocketConnector());
      expect(
        await adapter.checkElectrum(
          url: await _closedUrl(),
          network: ElectrumServerNetwork.bitcoinRegtest,
          validateDomain: false,
          timeout: 2,
        ),
        ElectrumServerStatus.offline,
      );
    },
  );
}
