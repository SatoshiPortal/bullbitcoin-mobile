import 'package:primitives/primitives.dart' show Failure;

sealed class AddressViewFailure extends Failure {
  const AddressViewFailure([super.logMessage]);
}

final class AddressViewWalletNotFoundFailure extends AddressViewFailure {
  const AddressViewWalletNotFoundFailure();
}

/// Deriving the address list or reading wallet usage failed.
final class AddressViewAddressesUnavailableFailure extends AddressViewFailure {
  const AddressViewAddressesUnavailableFailure([super.logMessage]);
}

final class AddressViewWriterBusyFailure extends AddressViewFailure {
  const AddressViewWriterBusyFailure();
}

final class AddressViewInvalidAddressFailure extends AddressViewFailure {
  const AddressViewInvalidAddressFailure();
}

final class AddressViewUnexpectedFailure extends AddressViewFailure {
  const AddressViewUnexpectedFailure([super.logMessage]);
}
