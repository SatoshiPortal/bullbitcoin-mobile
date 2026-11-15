import 'package:primitives/primitives.dart' show Failure;

sealed class AddressViewFailure extends Failure {
  const AddressViewFailure([super.logMessage]);
}

final class AddressViewWalletNotFoundFailure extends AddressViewFailure {
  const AddressViewWalletNotFoundFailure();
}

/// Deriving or enriching the address list failed (wallet database, BDK/LWK, or
/// label lookup).
final class AddressViewAddressesUnavailableFailure extends AddressViewFailure {
  const AddressViewAddressesUnavailableFailure([super.logMessage]);
}

final class AddressViewUnsupportedNetworkFailure extends AddressViewFailure {
  const AddressViewUnsupportedNetworkFailure();
}

final class AddressViewInvalidAddressFailure extends AddressViewFailure {
  const AddressViewInvalidAddressFailure();
}

final class AddressViewServerUnreachableFailure extends AddressViewFailure {
  const AddressViewServerUnreachableFailure([super.logMessage]);
}

final class AddressViewOwnershipUnavailableFailure extends AddressViewFailure {
  const AddressViewOwnershipUnavailableFailure([super.logMessage]);
}

final class AddressViewLabelFailure extends AddressViewFailure {
  const AddressViewLabelFailure([super.logMessage]);
}

final class AddressViewUnexpectedFailure extends AddressViewFailure {
  const AddressViewUnexpectedFailure([super.logMessage]);
}
