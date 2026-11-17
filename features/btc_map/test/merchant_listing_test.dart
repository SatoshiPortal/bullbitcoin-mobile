import 'package:btc_map/src/map_types.dart';
import 'package:flutter_test/flutter_test.dart';

Merchant _merchant(
  int id, {
  String? name,
  String? address,
  double latitude = 0,
  double longitude = 0,
  MerchantCategory? category,
}) => Merchant(
  id: id,
  location: GeoPoint(latitude: latitude, longitude: longitude),
  name: name ?? 'Shop $id',
  address: address,
  category: category,
);

void main() {
  final viewport = GeoBounds(south: -0.2, west: -0.2, north: 0.2, east: 0.2);

  group('nearby', () {
    test('lists only places in view, nearest to the centre first', () {
      final listing = MerchantListing.nearby([
        _merchant(1, latitude: 0.05),
        _merchant(2, latitude: 0.01),
        _merchant(3, latitude: 1),
        _merchant(4, longitude: -0.03),
      ], viewport: viewport);
      expect(listing.places.map((m) => m.id), [2, 4, 1]);
      expect(listing.total, 3);
      expect(listing.isTruncated, isFalse);
    });

    test('asks to zoom in rather than list a whole country', () {
      final listing = MerchantListing.nearby([
        _merchant(1),
      ], viewport: GeoBounds(south: -5, west: -5, north: 5, east: 5));
      expect(listing.isZoomedOut, isTrue);
      expect(listing.places, isEmpty);
      expect(listing.total, 0);
    });

    test('caps the list but counts every place in view', () {
      final merchants = [
        for (var i = 1; i <= MerchantListing.maxPlaces + 30; i++)
          _merchant(i, latitude: i / 100000),
      ];
      final listing = MerchantListing.nearby(merchants, viewport: viewport);
      expect(listing.places, hasLength(MerchantListing.maxPlaces));
      expect(listing.total, MerchantListing.maxPlaces + 30);
      expect(listing.isTruncated, isTrue);
    });

    test('counts every category, then filters by the picked one', () {
      final listing = MerchantListing.nearby(
        [
          _merchant(1, category: MerchantCategory.coffee),
          _merchant(2, category: MerchantCategory.coffee),
          _merchant(3, category: MerchantCategory.hotels),
          _merchant(4),
        ],
        viewport: viewport,
        category: MerchantCategory.coffee,
      );
      expect(listing.places.map((m) => m.id), unorderedEquals([1, 2]));
      expect(listing.total, 2);
      expect(listing.categories, {
        MerchantCategory.coffee,
        MerchantCategory.hotels,
      });
    });
  });

  group('search', () {
    test('searches every place, names starting with the query first', () {
      final listing = MerchantListing.search([
        _merchant(1, name: 'The Coffee Bar'),
        _merchant(2, name: 'Coffee Lab', latitude: 60),
        _merchant(3, name: 'Bakery', address: 'Coffee Street'),
        _merchant(4, name: 'coffee & co'),
      ], query: 'coffee');
      expect(listing.places.map((m) => m.id), [4, 2, 3, 1]);
      expect(listing.isZoomedOut, isFalse);
    });

    test('applies the category filter too', () {
      final listing = MerchantListing.search(
        [
          _merchant(1, name: 'Coffee', category: MerchantCategory.coffee),
          _merchant(2, name: 'Coffee hotel', category: MerchantCategory.hotels),
        ],
        query: 'coffee',
        category: MerchantCategory.hotels,
      );
      expect(listing.places.map((m) => m.id), [2]);
      expect(listing.categories, {
        MerchantCategory.coffee,
        MerchantCategory.hotels,
      });
    });
  });

  group('of', () {
    test('is empty until the map has reported a viewport', () {
      expect(
        MerchantListing.of([_merchant(1)], viewport: null).places,
        isEmpty,
      );
    });

    test('without a query, lists what is in view', () {
      final listing = MerchantListing.of([
        _merchant(1),
        _merchant(2, latitude: 40),
      ], viewport: viewport);
      expect(listing.places.map((m) => m.id), [1]);
    });

    test('a query searches beyond the viewport, even before one', () {
      final merchants = [_merchant(1, name: 'Coffee', latitude: 40)];
      expect(
        MerchantListing.of(merchants, viewport: null, query: 'cof').places,
        hasLength(1),
      );
      expect(
        MerchantListing.of(
          merchants,
          viewport: GeoBounds(south: -80, west: -180, north: 80, east: 180),
          query: 'cof',
        ).places,
        hasLength(1),
      );
    });

    test('a single letter does not search yet', () {
      final listing = MerchantListing.of(
        [_merchant(1, name: 'Coffee')],
        viewport: viewport,
        query: 'c',
      );
      expect(listing.places.map((m) => m.id), [1]);
      expect(MerchantListing.isSearch('c'), isFalse);
      expect(MerchantListing.isSearch(' co '), isTrue);
    });

    test('a blank query is no query', () {
      final listing = MerchantListing.of(
        [_merchant(1)],
        viewport: GeoBounds(south: -5, west: -5, north: 5, east: 5),
        query: '   ',
      );
      expect(listing.isZoomedOut, isTrue);
    });
  });
}
