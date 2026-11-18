import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('quote check', () {
    String? mismatchFor(int fee) => fee == 2 ? null : 'lockup amount';

    test('a match against the cached fees never refetches', () async {
      var refetches = 0;
      await requireQuote<int>(
        fees: () => 2,
        refetch: () async => refetches++,
        mismatchFor: mismatchFor,
      );
      expect(refetches, 0);
    });

    test('fees that moved since the quote are refetched once', () async {
      var cached = 1;
      var refetches = 0;
      await requireQuote<int>(
        fees: () => cached,
        refetch: () async {
          refetches++;
          cached = 2;
        },
        mismatchFor: mismatchFor,
      );
      expect(refetches, 1);
    });

    test('a mismatch against fresh fees is refused', () async {
      await expectLater(
        requireQuote<int>(
          fees: () => 1,
          refetch: () async {},
          mismatchFor: mismatchFor,
        ),
        throwsA(isA<SwapsException>()),
      );
    });

    test('fees that cannot be fetched are refused', () async {
      await expectLater(
        requireQuote<int>(
          fees: () => null,
          refetch: () async {},
          mismatchFor: mismatchFor,
        ),
        throwsA(isA<SwapsException>()),
      );
    });
  });

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
