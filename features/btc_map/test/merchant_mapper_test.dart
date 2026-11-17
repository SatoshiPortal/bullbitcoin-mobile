import 'package:btc_map/src/map_types.dart';
import 'package:btc_map/src/data/models/merchant_model.dart';
import 'package:btc_map/src/data/merchant_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MerchantModel.fromJson', () {
    test('reads the documented v4 fields', () {
      final model = MerchantModel.fromJson({
        'id': 28779,
        'lat': 49.1055648,
        'lon': -121.9641064,
        'name': 'The Owl and The Cat Bookery',
        'address': '45655 Tamihi Way',
        'opening_hours': 'Mo-Fr 11:00-17:30',
        'phone': '+1-604-846-6332',
        'website': 'https://owlandcat.ca',
        'updated_at': '2025-09-18T13:12:31.723Z',
      });
      expect(model.id, 28779);
      expect(model.openingHours, 'Mo-Fr 11:00-17:30');
      expect(model.updatedAt, DateTime.utc(2025, 9, 18, 13, 12, 31, 723));
      expect(model.isDeleted, isFalse);
    });

    test('reads the contact, payment and verification fields', () {
      final model = MerchantModel.fromJson({
        'id': 34352,
        'email': 'hello@shop.example',
        'instagram': 'https://www.instagram.com/shop',
        'description': 'Barber',
        'required_app_url': 'https://app.example',
        'osm:payment:onchain': 'no',
        'osm:payment:lightning': 'yes',
        'verified_at': '2026-01-29',
      });
      expect(model.email, 'hello@shop.example');
      expect(model.instagram, 'https://www.instagram.com/shop');
      expect(model.paymentOnchain, 'no');
      expect(model.paymentLightning, 'yes');
      expect(model.paymentLightningContactless, isNull);
      expect(model.verifiedAt, DateTime.utc(2026, 1, 29));
    });

    test('keeps the calendar day of verified_at in either API format', () {
      // A bare date parses as local midnight; it must not move to the day
      // before when the device is west of Greenwich.
      expect(
        MerchantModel.fromJson({'id': 1, 'verified_at': '2025-09-18T00:00:00Z'})
            .verifiedAt,
        DateTime.utc(2025, 9, 18),
      );
      expect(
        MerchantModel.fromJson({'id': 1, 'verified_at': '2025-09-18'})
            .verifiedAt,
        DateTime.utc(2025, 9, 18),
      );
    });

    test('asks the API for every field it reads', () {
      for (final field in [
        'verified_at',
        'email',
        'twitter',
        'facebook',
        'instagram',
        'telegram',
        'description',
        'required_app_url',
        'osm:payment:onchain',
        'osm:payment:lightning',
        'osm:payment:lightning_contactless',
      ]) {
        expect(MerchantModel.apiFields.split(','), contains(field));
      }
    });

    test('a full sync leaves deleted places out, an incremental one asks', () {
      // Asking for deleted_at makes the server include deleted places.
      expect(MerchantModel.apiFields.split(','), isNot(contains('deleted_at')));
      expect(MerchantModel.syncFields.split(','), contains('deleted_at'));
    });

    test('a list parse skips what is not a place instead of failing', () {
      final places = parseMerchantModels([
        {'id': 1, 'name': 'Good'},
        {'name': 'No id'},
        'not a place',
        {'id': 2, 'lat': 'not a number'},
      ]);
      expect(places.map((p) => p.id), [1, 2]);
      expect(places.last.lat, isNull);
      expect(() => parseMerchantModels({'id': 1}), throwsFormatException);
    });

    test('throws on a place without an integer id', () {
      expect(
        () => MerchantModel.fromJson({'name': 'x'}),
        throwsFormatException,
      );
      expect(() => MerchantModel.fromJson('not a map'), throwsFormatException);
    });

    test('round-trips through toJson for the cache', () {
      final model = MerchantModel.fromJson({
        'id': 1,
        'lat': 1.5,
        'lon': 2.5,
        'name': 'A',
        'email': 'a@b.example',
        'telegram': 'https://t.me/a',
        'osm:payment:lightning_contactless': 'yes',
        'verified_at': '2026-01-29',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      final copy = MerchantModel.fromJson(model.toJson());
      expect(copy.toJson(), model.toJson());
    });
  });

  group('toDomain', () {
    test('maps a valid place', () {
      final merchant = MerchantModel.fromJson({
        'id': 7,
        'lat': 10,
        'lon': 20,
        'name': 'Shop',
        'website': 'https://shop.example',
      }).toDomain();
      expect(merchant?.id, 7);
      expect(merchant?.location.latitude, 10);
      expect(merchant?.website, Uri.parse('https://shop.example'));
    });

    test('drops deleted places and places without a valid coordinate', () {
      final deleted = MerchantModel.fromJson({
        'id': 1,
        'lat': 1,
        'lon': 1,
        'deleted_at': DateTime.utc(2026).toIso8601String(),
      });
      expect(deleted.toDomain(), isNull);
      expect(MerchantModel.fromJson({'id': 2, 'lon': 1}).toDomain(), isNull);
      expect(
        MerchantModel.fromJson({'id': 3, 'lat': 95, 'lon': 1}).toDomain(),
        isNull,
      );
    });

    test('skips non-positive ids instead of crashing the entire sync', () {
      for (final id in [0, -1]) {
        expect(
          MerchantModel.fromJson({'id': id, 'lat': 1, 'lon': 1}).toDomain(),
          isNull,
        );
      }
    });

    test('keeps only http(s) links, so no other scheme can be launched', () {
      final merchant = MerchantModel.fromJson({
        'id': 1,
        'lat': 1,
        'lon': 1,
        'website': 'javascript:alert(1)',
        'instagram': 'tg://resolve?domain=x',
        'required_app_url': 'intent://evil#Intent;end',
      }).toDomain();
      expect(merchant?.website, isNull);
      expect(merchant?.socialLinks, isEmpty);
      expect(merchant?.requiredAppUrl, isNull);
    });

    test('files a place under its category from the BTC Map icon', () {
      MerchantCategory? categoryOf(String? icon) =>
          MerchantModel.fromJson({'id': 1, 'lat': 1, 'lon': 1, 'icon': icon})
              .toDomain()
              ?.category;
      expect(categoryOf('local_cafe'), MerchantCategory.coffee);
      expect(categoryOf('cafe'), MerchantCategory.coffee);
      expect(categoryOf('lunch_dining'), MerchantCategory.restaurants);
      expect(categoryOf('local_atm'), MerchantCategory.atms);
      expect(categoryOf('content_cut'), MerchantCategory.beauty);
      expect(categoryOf('spa'), isNull);
      expect(categoryOf(null), isNull);
    });

    test('maps payment tags, social links and verification', () {
      final merchant = MerchantModel.fromJson({
        'id': 42,
        'lat': 1,
        'lon': 1,
        'twitter': 'https://twitter.com/shop',
        'instagram': 'https://www.instagram.com/shop',
        'osm:payment:onchain': 'yes',
        'osm:payment:lightning': 'Yes ',
        'osm:payment:lightning_contactless': 'no',
        'verified_at': DateTime.utc(2026, 1, 29).toIso8601String(),
      }).toDomain();
      expect(merchant?.paymentMethods, {
        MerchantPaymentMethod.onchain,
        MerchantPaymentMethod.lightning,
      });
      expect(merchant?.socialLinks, [
        Uri.parse('https://twitter.com/shop'),
        Uri.parse('https://www.instagram.com/shop'),
      ]);
      expect(merchant?.verifiedAt, DateTime.utc(2026, 1, 29));
      expect(merchant?.btcMapUrl, Uri.parse('https://btcmap.org/merchant/42'));
    });
  });
}
