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

final class AddressViewUnexpectedFailure extends AddressViewFailure {
  const AddressViewUnexpectedFailure([super.logMessage]);
}
