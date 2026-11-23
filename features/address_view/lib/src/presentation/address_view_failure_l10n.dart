import 'package:address_view/address_view.dart';
import 'package:flutter/widgets.dart';

import 'address_view_l10n.dart';

extension AddressViewFailureL10n on AddressViewFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AddressViewWalletNotFoundFailure() =>
      context.loc.addressViewErrorWalletNotFound,
    AddressViewAddressesUnavailableFailure() ||
    AddressViewWriterBusyFailure() ||
    AddressViewInvalidAddressFailure() =>
      context.loc.addressViewErrorLoadFailed,
    AddressViewUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
