import 'package:bb_mobile/core/mempool/interface_adapters/validators/http_mempool_server_validator.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an onion server gets the Tor connect deadline', () {
    expect(
      HttpMempoolServerValidator.timeoutFor(
        Uri.parse(
          'http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion',
        ),
      ),
      torConnectDeadline,
    );
  });

  test('a clearnet server keeps a short validation timeout', () {
    expect(
      HttpMempoolServerValidator.timeoutFor(Uri.parse('https://mempool.space')),
      const Duration(seconds: 5),
    );
  });
}
