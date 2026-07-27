import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    await Bull.initLogs();
    await Bull.initFlutterRustBridgeDependencies();
  }

  const btcAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

  const lnurlStr =
      'lnurl1dp68gurn8ghj7um9wfmxjcm99e3k7mf0v9cxj0m385ekvcenxc6r2c35xvukxefcv5'
      'mkvv34x5ekzd3ev56nyd3hxqurzepexejxxepnxscrvwfnv9nxzcn9xq6xyefhvgcxxcmyxy'
      'mnserxfq5fns';

  // This decoder-compatible vector includes payment-secret metadata. Parsing
  // extracts its expiry timestamp but deliberately does not enforce wall time.
  const bolt11Invoice =
      'lnbc10u1p59tufasp53yuqahahgct058zglxvhezp9nyz5fvt2kn2lsl6mg9qgsts8c72s'
      'pp56hym2dpcyy0878h7q5h4t30cwclp9vd0tqpn4dns0a3mmspzkh9qdqqxqyp2xqcqz95r'
      'zjqg2n4jluz7ty6mn96krzje43zm7ylttjvcxcccg99tmm30s6lm4d6zzxeyqq28qqqqqqq'
      'qqqqqqqq9gq2y9qyysgqpmw883kkclyxpr2u8mg9pl47909yhtt83pjvt3qz3s9puyf39v'
      'dp4ar7zu47r4mfawkc2s99vm292udx9n3s5fnrjyngnsxkxn2l60qpn65s0t';

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

    test('Lightning URI with uppercase LNURL', () async {
      final result = await PaymentRequest.parse(
        'lightning:${lnurlStr.toUpperCase()}',
      );

      expect(result, isA<LnAddressPaymentRequest>());
      expect(
        (result as LnAddressPaymentRequest).address,
        lnurlStr.toUpperCase(),
      );
    });

    test('Uppercase Lightning URI with uppercase LNURL', () async {
      final result = await PaymentRequest.parse(
        'LIGHTNING:${lnurlStr.toUpperCase()}',
      );

      expect(result, isA<LnAddressPaymentRequest>());
      expect(
        (result as LnAddressPaymentRequest).address,
        lnurlStr.toUpperCase(),
      );
    });

    test('Lightning URI with Lightning Address', () async {
      final result = await PaymentRequest.parse(
        'lightning:ishi@walletofsatoshi.com',
      );

      expect(result, isA<LnAddressPaymentRequest>());
      expect(
        (result as LnAddressPaymentRequest).address,
        'ishi@walletofsatoshi.com',
      );
    });

    test('Lightning URI with Bolt11 invoice', () async {
      final result = await PaymentRequest.parse('lightning:$bolt11Invoice');

      expect(result, isA<Bolt11PaymentRequest>());
      expect((result as Bolt11PaymentRequest).invoice, bolt11Invoice);
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
