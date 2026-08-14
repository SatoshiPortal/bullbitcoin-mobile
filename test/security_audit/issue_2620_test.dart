import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2620
// Finding: a plaintext custom mempool server is accepted for fee estimation.
// Regression test for the fix.
void main() {
  group('Security audit #2620 plaintext custom fee server', () {
    test('HTTP custom server cannot control fee estimation by default', () {
      // The settings UI derives enableSsl=false when the user types an
      // http:// URL (MempoolUrlParser.parse) and passes it through
      // SetCustomMempoolServerRequest — this is that plaintext path.
      final result = MempoolServer.tryCreateCustom(
        url: 'http://fees.example.com',
        network: MempoolServerNetwork.bitcoinMainnet,
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
