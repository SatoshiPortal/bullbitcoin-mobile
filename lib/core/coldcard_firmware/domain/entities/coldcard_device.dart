/// Coldcard hardware models supported by the firmware update flow.
///
/// Distinct from the wallet-signing `SignerDeviceEntity`: this enum is the domain boundary for the firmware feature and maps to the `coldcard_firmware` package's model type in the data layer.
enum ColdcardDevice {
  q(displayName: 'COLDCARD Q'),
  mk4(displayName: 'COLDCARD Mk4');

  const ColdcardDevice({required this.displayName});

  /// Product name — not translated, it's a brand name.
  final String displayName;
}
