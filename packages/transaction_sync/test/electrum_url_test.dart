import 'package:test/test.dart';
import 'package:transaction_sync/src/data/electrum_sync.dart';

void main() {
  test('LWK host:port URLs use TLS for the BDK probe', () {
    expect(
      electrumClientUrl('liquid.example:50002'),
      'ssl://liquid.example:50002',
    );
    expect(electrumClientUrl('[::1]:50002'), 'ssl://[::1]:50002');
  });

  test('explicit transports remain unchanged', () {
    for (final url in [
      'ssl://bitcoin.example:50002',
      'tcp://localhost:50001',
    ]) {
      expect(electrumClientUrl(url), url);
    }
  });
}
