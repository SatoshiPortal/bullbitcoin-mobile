import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

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

    test('BIP21 with Bolt11 lightning param', () async {
      final input = 'bitcoin:$btcAddress?lightning=$bolt11Invoice';
      final result = await PaymentRequest.parse(input);
      expect(result, isA<Bip21PaymentRequest>());
      final bip21 = result as Bip21PaymentRequest;
      expect(bip21.address.toLowerCase(), btcAddress);
      expect(bip21.lightning, bolt11Invoice);
      expect(bip21.network, Network.bitcoinMainnet);
    });

    test(
      'HTTPS URL with percent-encoded LNAddress in lightning param',
      () async {
        const input =
            'https://admin.bullbitcoin.com/abc'
            '?lightning=ishi%40walletofsatoshi.com&label=pleasefundme';
        final result = await PaymentRequest.parse(input);
        expect(result, isA<LnAddressPaymentRequest>());
        expect(
          (result as LnAddressPaymentRequest).address,
          'ishi@walletofsatoshi.com',
        );
      },
    );
  });
}
