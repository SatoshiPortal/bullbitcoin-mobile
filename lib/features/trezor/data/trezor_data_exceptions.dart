/// Internal data-layer exceptions for the Trezor slice. These never cross
/// the repository boundary — `TrezorDeviceRepositoryImpl._mapError` maps
/// them to a [TrezorError] variant first.
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

/// Thrown by `TrezorDeviceRepositoryImpl._toAccount` when Trezor's response
/// doesn't contain a usable descriptor field — the master fingerprint can
/// only be extracted from BIP-380 descriptor's origin section. The
/// `trezor_connect` package documents `descriptor` as not available for
/// Model One (and possibly other devices with older firmware), so the
/// repository impl translates this to `TrezorError.missingDescriptor`
/// at the layer boundary.
class TrezorMissingDescriptorException implements Exception {
  /// The raw descriptor returned by Trezor — `null` if no descriptor field
  /// was present, otherwise the string that failed BIP-380 parsing.
  final String? rawDescriptor;

  const TrezorMissingDescriptorException({this.rawDescriptor});
}
