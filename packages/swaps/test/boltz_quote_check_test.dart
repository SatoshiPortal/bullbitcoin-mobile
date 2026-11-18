import 'package:swaps/src/data/boltz_api.dart';
import 'package:test/test.dart';

void main() {
  group('chain swap', () {
    String? check({int lockup = 100000, int? onchain}) => chainQuoteMismatch(
      lockupAmount: lockup,
      onchainAmount: onchain,
      amountSat: 100000,
      percentage: 0.1,
      serverFee: 1500,
    );

    test('a lockup of the requested amount and the quoted fees passes', () {
      expect(check(onchain: 100000 - 100 - 1500), isNull);
      expect(check(onchain: 100000), isNull);
    });

    test('a lockup other than the requested amount is refused', () {
      expect(check(lockup: 100001, onchain: 98400), 'lockup amount');
    });

    test('Boltz locking less than the quote allows is refused', () {
      expect(check(onchain: 100000 - 100 - 1500 - 2), 'server lockup amount');
    });

    test('Boltz leaving out its lockup amount is refused', () {
      expect(check(), 'server lockup amount');
    });
  });

  group('submarine swap', () {
    String? check(int expected) => submarineQuoteMismatch(
      invoiceSat: 50000,
      expectedAmount: expected,
      percentage: 0.1,
      minerFees: 300,
    );

    test('the invoice plus the quoted fees passes, cheaper too', () {
      expect(check(50000 + 50 + 300), isNull);
      expect(check(50000), isNull);
    });

    test('asking for more than the quoted fees is refused', () {
      expect(check(50000 + 50 + 300 + 2), 'expected amount');
    });
  });

  group('reverse swap', () {
    String? check({int invoice = 80000, int? onchain}) => reverseQuoteMismatch(
      invoiceSat: invoice,
      onchainAmount: onchain,
      outAmount: 80000,
      percentage: 0.25,
      lockupFee: 400,
    );

    test('our amount and a lockup within the quoted fees pass', () {
      expect(check(onchain: 80000 - 200 - 400), isNull);
    });

    test('an invoice for another amount is refused', () {
      expect(check(invoice: 80001, onchain: 79400), 'invoice amount');
    });

    test('a lockup below the quote is refused', () {
      expect(check(onchain: 80000 - 200 - 400 - 2), 'lockup amount');
    });

    test('Boltz leaving out its lockup amount is refused', () {
      expect(check(), 'lockup amount');
    });
  });
}
