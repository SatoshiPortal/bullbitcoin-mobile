import 'package:btc_map/src/map_types.dart';
import 'package:flutter_test/flutter_test.dart';

Merchant _merchant({int id = 1, String? name, String? address}) => Merchant(
  id: id,
  location: GeoPoint(latitude: 45.5, longitude: -73.6),
  name: name,
  address: address,
);

void main() {
  group('GeoPoint', () {
    test('accepts the full valid range', () {
      expect(() => GeoPoint(latitude: -90, longitude: -180), returnsNormally);
      expect(() => GeoPoint(latitude: 90, longitude: 180), returnsNormally);
    });

    test('rejects out-of-range and non-finite coordinates', () {
      expect(() => GeoPoint(latitude: 90.1, longitude: 0), throwsArgumentError);
      expect(
        () => GeoPoint(latitude: 0, longitude: -180.1),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: double.nan, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: double.infinity),
        throwsArgumentError,
      );
    });
  });

  group('Merchant', () {
    test('rejects a non-positive id', () {
      expect(() => _merchant(id: 0), throwsArgumentError);
    });

    test('normalises blank text to null', () {
      final merchant = _merchant(name: '  ', address: '');
      expect(merchant.name, isNull);
      expect(merchant.address, isNull);
    });

    test('matches name or address, ignoring case and surrounding spaces', () {
      final merchant = _merchant(
        name: 'Café Bitcoin',
        address: '12 Rue Saint-Denis',
      );
      expect(merchant.matches('café'), isTrue);
      expect(merchant.matches(' SAINT-DENIS '), isTrue);
      expect(merchant.matches('bakery'), isFalse);
    });

    test('an empty query matches nothing', () {
      expect(_merchant(name: 'Anything').matches('   '), isFalse);
    });

    test('a merchant without name or address never matches', () {
      expect(_merchant().matches('a'), isFalse);
    });

    test('keeps a plausible email and drops a malformed one', () {
      Merchant withEmail(String email) => Merchant(
        id: 1,
        location: GeoPoint(latitude: 0, longitude: 0),
        email: email,
      );
      expect(withEmail(' shop@example.com ').email, 'shop@example.com');
      expect(withEmail('not an email').email, isNull);
      expect(withEmail('a@b@c').email, isNull);
      expect(withEmail('@example.com').email, isNull);
      expect(withEmail('shop@').email, isNull);
      expect(withEmail('a b@example.com').email, isNull);
    });

    test('splits opening hours into their rules', () {
      final merchant = Merchant(
        id: 1,
        location: GeoPoint(latitude: 0, longitude: 0),
        openingHours: 'Mo-Fr 09:00-17:00; Sa 10:00-14:00;; ',
      );
      expect(merchant.openingHoursRules, [
        'Mo-Fr 09:00-17:00',
        'Sa 10:00-14:00',
      ]);
      expect(_merchant().openingHoursRules, isEmpty);
    });
  });

  group('Merchant.verificationAt', () {
    final now = DateTime.utc(2026, 11, 15, 10);

    Merchant verified(DateTime? day) => Merchant(
      id: 1,
      location: GeoPoint(latitude: 0, longitude: 0),
      verifiedAt: day,
    );

    test('is recent within a year, as on btcmap.org', () {
      expect(
        verified(DateTime.utc(2026, 11, 15)).verificationAt(now),
        MerchantVerification.recent,
      );
      expect(
        verified(DateTime.utc(2025, 11, 16)).verificationAt(now),
        MerchantVerification.recent,
      );
    });

    test('is outdated from one year on', () {
      expect(
        verified(DateTime.utc(2025, 11, 15)).verificationAt(now),
        MerchantVerification.outdated,
      );
      expect(
        verified(DateTime.utc(2019)).verificationAt(now),
        MerchantVerification.outdated,
      );
    });

    test('is never without a verification date', () {
      expect(verified(null).verificationAt(now), MerchantVerification.never);
    });
  });

  group('inCategory', () {
    final merchants = [
      Merchant(
        id: 1,
        location: GeoPoint(latitude: 0, longitude: 0),
        category: MerchantCategory.coffee,
      ),
      Merchant(id: 2, location: GeoPoint(latitude: 0, longitude: 0)),
    ];

    test('keeps the picked category only', () {
      expect(merchants.inCategory(MerchantCategory.coffee).map((m) => m.id), [
        1,
      ]);
    });

    test('returns the same list for every category', () {
      // The map re-uploads its pins whenever it gets a different list.
      expect(identical(merchants.inCategory(null), merchants), isTrue);
    });
  });
}
