import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:flutter/widgets.dart';

extension AddressViewFailureL10n on AddressViewFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AddressViewWalletNotFoundFailure() =>
      context.loc.addressViewErrorWalletNotFound,
    AddressViewAddressesUnavailableFailure() =>
      context.loc.addressViewErrorLoadFailed,
    AddressViewUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
