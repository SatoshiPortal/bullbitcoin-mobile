import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:btc_map/src/data/models/merchant_model.dart';

extension MerchantMapper on MerchantModel {
  /// The entity, or null for a place the map cannot show: deleted, or without
  /// a valid coordinate.
  Merchant? toDomain() {
    final latitude = lat;
    final longitude = lon;
    if (id <= 0 || isDeleted || latitude == null || longitude == null) {
      return null;
    }
    if (!GeoPoint.isValid(latitude: latitude, longitude: longitude)) {
      return null;
    }
    return Merchant(
      id: id,
      location: GeoPoint(latitude: latitude, longitude: longitude),
      name: name,
      category: _categoryOf(icon),
      address: address,
      openingHours: openingHours,
      phone: phone,
      email: email,
      description: description,
      website: _webUri(website),
      socialLinks: [
        for (final link in [twitter, facebook, instagram, telegram])
          ?_webUri(link),
      ],
      requiredAppUrl: _webUri(requiredAppUrl),
      btcMapUrl: Uri.https('btcmap.org', '/merchant/$id'),
      paymentMethods: {
        if (_isYes(paymentOnchain)) MerchantPaymentMethod.onchain,
        if (_isYes(paymentLightning)) MerchantPaymentMethod.lightning,
        if (_isYes(paymentLightningContactless))
          MerchantPaymentMethod.lightningContactless,
      },
      verifiedAt: verifiedAt,
    );
  }
}

/// BTC Map files each place under a Material icon name. The table is
/// btcmap.org's own (src/lib/categoryMapping.ts), plus `cafe`, which the API
/// also uses for coffee shops.
MerchantCategory? _categoryOf(String? icon) => switch (icon?.trim()) {
  'restaurant' ||
  'local_pizza' ||
  'lunch_dining' => MerchantCategory.restaurants,
  'storefront' || 'local_mall' => MerchantCategory.shopping,
  'local_grocery_store' => MerchantCategory.groceries,
  'local_cafe' || 'cafe' => MerchantCategory.coffee,
  'local_atm' => MerchantCategory.atms,
  'hotel' => MerchantCategory.hotels,
  'content_cut' => MerchantCategory.beauty,
  _ => null,
};

bool _isYes(String? tag) => tag?.trim().toLowerCase() == 'yes';

/// Only http(s) links leave the app: a crafted OpenStreetMap tag must not be
/// able to launch an arbitrary scheme handler.
Uri? _webUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.host.isEmpty) return null;
  return (uri.scheme == 'https' || uri.scheme == 'http') ? uri : null;
}
