import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:flutter_test/flutter_test.dart';

// A complete, valid BIP21 payjoin URI as produced by the payjoin PDK:
// uppercase scheme+host, '+' fragment separators, '#' as %23, clean '://'.
const pdkPjUri =
    'bitcoin:tb1q6q6de88mj8qkg0q5lupmpfexwnqjsr4d2gvx2p'
    '?pj=HTTPS://PAYJO.IN/TXJCGKTKXLUUZ'
    '%23EX1WKV8CEC+OH1QYPM59NK2LXXS4890SUAXXYT25Z2VAPHP0X7YEYCJXGWAG6UG9ZU6NQ'
    '+RK1Q0DJS3VVDXWQQTLQ8022QGXSX7ML9PHZ6EDSF6AKEWQG758JPS2EV';

const pj =
    'HTTPS://PAYJO.IN/TXJCGKTKXLUUZ'
    '%23EX1WKV8CEC+OH1QYPM59NK2LXXS4890SUAXXYT25Z2VAPHP0X7YEYCJXGWAG6UG9ZU6NQ'
    '+RK1Q0DJS3VVDXWQQTLQ8022QGXSX7ML9PHZ6EDSF6AKEWQG758JPS2EV';

void main() {
  group('ReceiveState.buildPayjoinPaymentRequest', () {
    test('keeps the pj endpoint byte-identical (no over-encoding)', () {
      final out = ReceiveState.buildPayjoinPaymentRequest(
        pjUri: pdkPjUri,
        amountBtc: 0,
        note: '',
      );
      expect(out.contains('HTTPS://'), isTrue);
      expect(out.contains('%3A%2F%2F'), isFalse, reason: ':// not encoded');
      expect(out.contains('pj=$pj'), isTrue, reason: 'pj unchanged');
    });

    test('injects pjos=0 when the PDK omits it', () {
      final out = ReceiveState.buildPayjoinPaymentRequest(
        pjUri: pdkPjUri,
        amountBtc: 0,
        note: '',
      );
      expect(out.contains('pjos=0'), isTrue);
    });

    test('does not duplicate pjos when the PDK already supplied it', () {
      final withPjos =
          'bitcoin:tb1q6q6de88mj8qkg0q5lupmpfexwnqjsr4d2gvx2p?pjos=1&pj=$pj';
      final out = ReceiveState.buildPayjoinPaymentRequest(
        pjUri: withPjos,
        amountBtc: 0,
        note: '',
      );
      expect('pjos='.allMatches(out).length, equals(1));
      expect(out.contains('pjos=1'), isTrue);
    });

    test('appends amount and message, with pj remaining last', () {
      final out = ReceiveState.buildPayjoinPaymentRequest(
        pjUri: pdkPjUri,
        amountBtc: 0.00666666,
        note: 'Order 9XWGG',
      );
      expect(out.contains('amount=0.00666666'), isTrue);
      expect(out.contains('message=Order+9XWGG'), isTrue);
      expect(out.contains('pjos=0'), isTrue);
      // pj must be the final parameter (BIP-77 SHOULD) and still clean.
      expect(out.endsWith('pj=$pj'), isTrue);
      expect(out.contains('%3A%2F%2F'), isFalse);
    });

    test('returns the URI untouched when there is nothing to add', () {
      final withPjos =
          'bitcoin:tb1q6q6de88mj8qkg0q5lupmpfexwnqjsr4d2gvx2p?pjos=0&pj=$pj';
      final out = ReceiveState.buildPayjoinPaymentRequest(
        pjUri: withPjos,
        amountBtc: 0,
        note: '',
      );
      expect(out, equals(withPjos));
    });
  });

  group('generated URI is consumable by the bip21_uri decoder', () {
    test('the pj endpoint survives a decode round-trip', () {
      final generated = ReceiveState.buildPayjoinPaymentRequest(
        pjUri: pdkPjUri,
        amountBtc: 0.00666666,
        note: 'Order 9XWGG',
      );

      final decoded = bip21.decode(generated);
      // pj is already in the canonical (uppercase, '+') form the decoder
      // normalizes to, so it must come back byte-identical.
      expect(decoded.options['pj'], equals(pj));
      expect(decoded.options['pjos'], equals('0'));
      expect(decoded.amount, equals(0.00666666));
      expect(decoded.message, equals('Order 9XWGG'));
      expect(decoded.address,
          equals('tb1q6q6de88mj8qkg0q5lupmpfexwnqjsr4d2gvx2p'));
    });
  });
}
