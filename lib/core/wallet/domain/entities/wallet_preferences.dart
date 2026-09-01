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

/// One recovery write guarded by the preference state that was classified.
final class WalletPreferencesRecoveryUpdate {
  final WalletPreferences expected;
  final WalletPreferences recovered;

  WalletPreferencesRecoveryUpdate({
    required this.expected,
    required this.recovered,
  }) {
    if (expected.walletRef != recovered.walletRef) {
      throw ArgumentError('wallet preference recovery identity changed');
    }
  }
}

final class WalletPreferencesRecoveryApplyResult {
  final Set<String> appliedWalletRefs;
  final Set<String> conflictedWalletRefs;

  WalletPreferencesRecoveryApplyResult({
    required Set<String> appliedWalletRefs,
    required Set<String> conflictedWalletRefs,
  }) : appliedWalletRefs = Set.unmodifiable(appliedWalletRefs),
       conflictedWalletRefs = Set.unmodifiable(conflictedWalletRefs) {
    if (this.appliedWalletRefs
        .intersection(this.conflictedWalletRefs)
        .isNotEmpty) {
      throw ArgumentError('wallet preference recovery result overlaps');
    }
  }
}
