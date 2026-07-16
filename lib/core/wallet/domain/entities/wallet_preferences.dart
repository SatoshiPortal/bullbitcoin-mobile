/// Portable, user-authored wallet preferences currently stored by the app.
///
/// Nullable values mean the preference is not represented in storage. Callers
/// must not replace that absence with a product/UI default during export.
final class WalletPreferences {
  final String walletRef;
  final String? label;
  final bool? hideOnHome;
  final bool? autoSweepEnabled;

  factory WalletPreferences({
    required String walletRef,
    String? label,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    if (walletRef.isEmpty) {
      throw ArgumentError.value(walletRef, 'walletRef', 'must not be empty');
    }
    return WalletPreferences._(
      walletRef: walletRef,
      label: label,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    );
  }

  const WalletPreferences._({
    required this.walletRef,
    required this.label,
    required this.hideOnHome,
    required this.autoSweepEnabled,
  });

  bool get hasRepresentedValue =>
      label != null || hideOnHome != null || autoSweepEnabled != null;
}
