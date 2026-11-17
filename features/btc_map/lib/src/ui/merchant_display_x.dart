import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';

/// The verified badge for a recent confirmation, a warning sign otherwise.
extension MerchantVerificationDisplay on MerchantVerification {
  IconData get icon => switch (this) {
    MerchantVerification.recent => BullIcons.verified,
    MerchantVerification.outdated ||
    MerchantVerification.never => BullIcons.warningAmber,
  };

  Color color(BuildContext context) => switch (this) {
    MerchantVerification.recent => context.bull.success,
    MerchantVerification.outdated ||
    MerchantVerification.never => context.bull.warning,
  };

  /// The one-word form used in the list.
  String shortLabel(BuildContext context) => switch (this) {
    MerchantVerification.recent => context.btcMapLoc.merchantMapVerified,
    MerchantVerification.outdated => context.btcMapLoc.merchantMapOutdated,
    MerchantVerification.never => context.btcMapLoc.merchantMapNotVerified,
  };
}

extension MerchantPaymentMethodDisplay on MerchantPaymentMethod {
  String label(BuildContext context) => switch (this) {
    MerchantPaymentMethod.onchain =>
      context.btcMapLoc.merchantMapPaymentOnchain,
    MerchantPaymentMethod.lightning =>
      context.btcMapLoc.merchantMapPaymentLightning,
    MerchantPaymentMethod.lightningContactless =>
      context.btcMapLoc.merchantMapPaymentLightningContactless,
  };
}

extension MerchantCategoryDisplay on MerchantCategory? {
  /// Null is a place none of the filters covers.
  IconData get icon => switch (this) {
    MerchantCategory.restaurants => BullIcons.restaurant,
    MerchantCategory.shopping => BullIcons.storefront,
    MerchantCategory.groceries => BullIcons.localGroceryStore,
    MerchantCategory.coffee => BullIcons.localCafe,
    MerchantCategory.atms => BullIcons.localAtm,
    MerchantCategory.hotels => BullIcons.hotel,
    MerchantCategory.beauty => BullIcons.contentCut,
    null => BullIcons.currencyBitcoin,
  };

  /// Null is the "all" filter.
  String label(BuildContext context) => switch (this) {
    MerchantCategory.restaurants =>
      context.btcMapLoc.merchantMapCategoryRestaurants,
    MerchantCategory.shopping => context.btcMapLoc.merchantMapCategoryShopping,
    MerchantCategory.groceries =>
      context.btcMapLoc.merchantMapCategoryGroceries,
    MerchantCategory.coffee => context.btcMapLoc.merchantMapCategoryCoffee,
    MerchantCategory.atms => context.btcMapLoc.merchantMapCategoryAtms,
    MerchantCategory.hotels => context.btcMapLoc.merchantMapCategoryHotels,
    MerchantCategory.beauty => context.btcMapLoc.merchantMapCategoryBeauty,
    null => context.btcMapLoc.merchantMapCategoryAll,
  };
}
