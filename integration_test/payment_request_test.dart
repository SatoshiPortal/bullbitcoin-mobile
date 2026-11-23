import 'package:primitives/primitives.dart' show BitcoinNetwork;

import 'initialization_result.dart';

import 'package:satoshifier/liquid_address.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/init.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

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
      expect(bip21.network, BitcoinNetwork.mainnet);
    });

    test('BIP21 with Bolt11 lightning param', () async {
      final input = 'bitcoin:$btcAddress?lightning=$bolt11Invoice';
      final result = await PaymentRequest.parse(input);
      expect(result, isA<Bip21PaymentRequest>());
      final bip21 = result as Bip21PaymentRequest;
      expect(bip21.address.toLowerCase(), btcAddress);
      expect(bip21.lightning, bolt11Invoice);
      expect(bip21.network, BitcoinNetwork.mainnet);
    });

    test('HTTPS URL with a percent-encoded LNAddress is rejected', () async {
      const input =
          'https://admin.bullbitcoin.com/abc'
          '?lightning=ishi%40walletofsatoshi.com&label=pleasefundme';
      expect(
        () => PaymentRequest.parse(input),
        throwsA('Invalid payment request'),
      );
    });
  });

  group('Liquid address confidentiality (security audit)', () {
    // Derives a real (standard, confidential) address pair from a known
    // P2WPKH scriptPubkey, so the test runs on genuinely valid addresses.
    late final lwk.Address pair;
    setUpAll(() async {
      pair = await lwk.Address.addressFromScript(
        network: lwk.LiquidNetwork.mainnet,
        // P2WPKH scriptPubkey: OP_0 <20 bytes>.
        script: '0014${'22' * 20}',
        blindingKey: '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
      );
    });

    test('the helper classifies both address forms correctly', () {
      expect(isConfidentialLiquidAddress(pair.confidential), isTrue);
      expect(isConfidentialLiquidAddress(pair.standard), isFalse);
    });

    test('the parser accepts an unconfidential Liquid address', () async {
      expect(
        await PaymentRequest.parse(pair.standard),
        isA<LiquidPaymentRequest>(),
      );
    });
  });
}
