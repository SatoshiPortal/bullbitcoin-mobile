import 'package:bull_map/bull_map.dart';
import 'package:bull_ui/bull_ui.dart';

import 'package:bb_mobile/core/utils/build_context_x.dart';

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
    MerchantVerification.recent => context.loc.merchantMapVerified,
    MerchantVerification.outdated => context.loc.merchantMapOutdated,
    MerchantVerification.never => context.loc.merchantMapNotVerified,
  };
}

extension MerchantPaymentMethodDisplay on MerchantPaymentMethod {
  String label(BuildContext context) => switch (this) {
    MerchantPaymentMethod.onchain => context.loc.merchantMapPaymentOnchain,
    MerchantPaymentMethod.lightning => context.loc.merchantMapPaymentLightning,
    MerchantPaymentMethod.lightningContactless =>
      context.loc.merchantMapPaymentLightningContactless,
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
    MerchantCategory.restaurants => context.loc.merchantMapCategoryRestaurants,
    MerchantCategory.shopping => context.loc.merchantMapCategoryShopping,
    MerchantCategory.groceries => context.loc.merchantMapCategoryGroceries,
    MerchantCategory.coffee => context.loc.merchantMapCategoryCoffee,
    MerchantCategory.atms => context.loc.merchantMapCategoryAtms,
    MerchantCategory.hotels => context.loc.merchantMapCategoryHotels,
    MerchantCategory.beauty => context.loc.merchantMapCategoryBeauty,
    null => context.loc.merchantMapCategoryAll,
  };
}
