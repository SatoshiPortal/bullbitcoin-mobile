import '../entities/geo_bounds.dart';
import '../entities/merchant.dart';
import '../entities/merchant_listing.dart';

/// Selects the visible pins and list for one map interaction, entirely offline.
class SelectMerchantsUsecase {
  const SelectMerchantsUsecase();

  ({List<Merchant> pins, MerchantListing listing}) execute(
    List<Merchant> merchants, {
    required GeoBounds? viewport,
    required String query,
    required MerchantCategory? category,
    List<Merchant>? unchangedPins,
  }) => (
    pins: unchangedPins ?? merchants.inCategory(category),
    listing: MerchantListing.of(
      merchants,
      viewport: viewport,
      query: query,
      category: category,
    ),
  );
}
