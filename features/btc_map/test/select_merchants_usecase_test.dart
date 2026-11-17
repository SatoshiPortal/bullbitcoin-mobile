import 'package:btc_map/src/domain/usecases/select_merchants_usecase.dart';
import 'package:btc_map/src/map_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters pins by category and searches the list without filtering pins by query', () {
    final coffee = Merchant(
      id: 1,
      location: GeoPoint(latitude: 0, longitude: 0),
      name: 'Coffee',
      category: MerchantCategory.coffee,
    );
    final hotel = Merchant(
      id: 2,
      location: GeoPoint(latitude: 0, longitude: 0),
      name: 'Hotel',
      category: MerchantCategory.hotels,
    );
    final selected = const SelectMerchantsUsecase().execute(
      [coffee, hotel],
      viewport: null,
      query: 'missing',
      category: MerchantCategory.coffee,
    );
    expect(selected.pins, [coffee]);
    expect(selected.listing.places, isEmpty);
    final searched = const SelectMerchantsUsecase().execute(
      [coffee, hotel],
      viewport: null,
      query: 'coffee',
      category: MerchantCategory.coffee,
      unchangedPins: selected.pins,
    );
    expect(searched.pins, same(selected.pins));
    expect(searched.listing.places, [coffee]);
  });
}
