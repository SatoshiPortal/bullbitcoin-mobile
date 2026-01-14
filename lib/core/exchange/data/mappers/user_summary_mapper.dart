import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_address.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';

class UserSummaryMapper {
  static UserSummary fromModelToEntity(UserSummaryModel model) {
    return UserSummary(
      userNumber: model.userNumber,
      userId: model.userId,
      groups: model.groups,
      profile: _mapUserProfile(model.profile),
      email: model.email,
      balances: model.balances.map(_mapUserBalance).toList(),
      language: model.language,
      currency: model.currency,
      dca: model.dca.toEntity(),
      autoBuy: _mapUserAutoBuy(model.autoBuy),
      address: model.address != null ? _mapUserAddress(model.address!) : null,
    );
  }

  static UserAddress _mapUserAddress(UserAddressModel model) {
    return UserAddress(
      street1: model.street1,
      street2: model.street2,
      city: model.city,
      province: model.province,
      postalCode: model.postalCode,
      countryCode: model.countryCode,
    );
  }

  static UserProfile _mapUserProfile(UserProfileModel model) {
    return UserProfile(firstName: model.firstName, lastName: model.lastName);
  }

  static UserBalance _mapUserBalance(UserBalanceModel model) {
    return UserBalance(amount: model.amount, currencyCode: model.currencyCode);
  }

  static UserAutoBuy _mapUserAutoBuy(UserAutoBuyModel model) {
    return UserAutoBuy(
      isActive: model.isActive,
      addresses: _mapUserAutoBuyAddresses(model.addresses),
    );
  }

  static UserAutoBuyAddresses _mapUserAutoBuyAddresses(
    UserAutoBuyAddressesModel model,
  ) {
    return UserAutoBuyAddresses(
      bitcoin: model.bitcoin,
      lightning: model.lightning,
      liquid: model.liquid,
    );
  }
}
