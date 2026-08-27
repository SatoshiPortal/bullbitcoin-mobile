// Run with: fvm flutter test test/core_test/utils/payment_request_test.dart
// Requires native FFI (bdk) — use `flutter test`, not `dart test`.
// The HTTPS/LNAddress test (needs boltz FFI + network) lives in
// integration_test/payment_request_test.dart.

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const btcAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

  const lnurlStr =
      'lnurl1dp68gurn8ghj7um9wfmxjcm99e3k7mf0v9cxj0m385ekvcenxc6r2c35xvukxefcv5'
      'mkvv34x5ekzd3ev56nyd3hxqurzepexejxxepnxscrvwfnv9nxzcn9xq6xyefhvgcxxcmyxy'
      'mnserxfq5fns';

  const bolt11Invoice =
      'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq'
      'dq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2aw'
      'hz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';

  group('PaymentRequest.parse', () {
    // bitcoin: URI whose lightning param is a LNURL with extra query params
    // (label, message). The parser must return bip21 with the bare lnurl string
    // in lightning — not the whole "lnurl1…&label=…" fragment.
    test('BIP21 with LNURL lightning param, label, and message', () async {
      final input =
          'bitcoin:$btcAddress?lightning=$lnurlStr&label=Donation&message=Thanks';
      final result = await PaymentRequest.parse(input);
      expect(result, isA<Bip21PaymentRequest>());
      final bip21 = result as Bip21PaymentRequest;
      expect(bip21.address.toLowerCase(), btcAddress);
      expect(bip21.lightning, lnurlStr);
      expect(bip21.label, 'Donation');
      expect(bip21.message, 'Thanks');
      expect(bip21.network, Network.bitcoinMainnet);
    });

    // bitcoin: URI whose lightning param is a standard Bolt11 invoice
    // (2500u = 0.0025 BTC = 250 000 sats).
    test('BIP21 with Bolt11 lightning param', () async {
      final input = 'bitcoin:$btcAddress?lightning=$bolt11Invoice';
      final result = await PaymentRequest.parse(input);
      expect(result, isA<Bip21PaymentRequest>());
      final bip21 = result as Bip21PaymentRequest;
      expect(bip21.address.toLowerCase(), btcAddress);
      expect(bip21.lightning, bolt11Invoice);
      expect(bip21.network, Network.bitcoinMainnet);
    });
  });
}
