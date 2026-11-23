import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2620
// Finding: a plaintext custom mempool server is accepted for fee estimation.
// Regression test for the fix.
void main() {
  group('Security audit #2620 plaintext custom fee server', () {
    test('HTTP custom server cannot control fee estimation by default', () {
      // The settings UI derives enableSsl=false when the user types an
      // http:// URL (MempoolUrlParser.parse) and passes it through
      // Mempool.servers.store — this is that plaintext path.
      final result = MempoolServer.tryCreateCustom(
        url: 'http://fees.example.com',
        network: BitcoinNetwork.mainnet,
        enableSsl: false,
      );
      final server = result.fold(
        (value) => value,
        (_) => throw StateError('rejected'),
      );
      expect(server.isCustom, isTrue);
      expect(server.enableSsl, isFalse);
      expect(server.canUseForFeeEstimation, isFalse);
      expect(server.fullUrl, 'http://fees.example.com');
    });
  });
}
