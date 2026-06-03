/// Framework-layer exceptions for the Trezor slice.
///
/// Thrown by `TrezorConnectDatasource.verifyAddress` when Trezor returns an
/// address that doesn't match the one we asked it to display.
class TrezorAddressMismatchException implements Exception {
  final String expected;
  final String returned;
  const TrezorAddressMismatchException({
    required this.expected,
    required this.returned,
  });
}
