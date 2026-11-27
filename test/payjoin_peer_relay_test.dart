import 'package:flutter_test/flutter_test.dart';

import '../integration_test/payjoin_peer_relay.dart';

void main() {
  test('the peer uses the other mailroom for either receiver directory', () {
    for (final (directory, expectedRelay) in [
      ('https://localhost:8040/session', 'https://127.0.0.1:8041'),
      ('https://127.0.0.1:8041/session', 'https://localhost:8040'),
    ]) {
      final paymentUri = Uri(
        scheme: 'bitcoin',
        path: 'bcrt1fixture',
        queryParameters: {'pj': directory},
      );
      expect(payjoinPeerRelay(paymentUri.toString()).toString(), expectedRelay);
    }
  });

  test('the peer rejects unknown or missing directories', () {
    for (final paymentUri in [
      'bitcoin:bcrt1fixture',
      'bitcoin:bcrt1fixture?pj=https%3A%2F%2Fexample.com%2Fsession',
    ]) {
      expect(() => payjoinPeerRelay(paymentUri), throwsFormatException);
    }
  });
}
