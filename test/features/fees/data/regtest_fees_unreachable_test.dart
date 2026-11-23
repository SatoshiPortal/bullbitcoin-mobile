import 'package:electrum/testing.dart';

import 'dart:io';

import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:mempool/mempool.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
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
  test(
    'unreachable regtest Electrum reports a retryable connection failure',
    () async {
      final connection = WalletConnection(
        url: await _closedUrl(),
        retry: 0,
        timeout: const Duration(seconds: 2),
        stopGap: 20,
        validateDomain: false,
      );
      final mempool = _Mempool();
      final port = _RegtestConnection(connection);
      final fees = Fees.open(
        connections: port,
        mempool: mempool,
        readPreference: (_) async => null,
        writePreference: (_, _) async {},
      );

      expect(
        await fees.estimate(BitcoinNetwork.regtest),
        isA<Err<FeeOptions, FeesFailure>>(),
      );
      expect(port.retryable, isTrue);
      verifyZeroInteractions(mempool);
    },
  );

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

class _Mempool extends Mock implements Mempool {}

class _RegtestConnection implements WalletConnectionPort {
  final WalletConnection connection;
  bool retryable = false;

  _RegtestConnection(this.connection);

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    expect(network, BitcoinNetwork.regtest);
    final result = await operation(connection);
    if (result case Err(:final failure)) {
      retryable = mayRetry(failure);
    }
    return result;
  }
}
