/// The one-directional coupling between a wallet's two behavior switches.
///
/// Hiding a wallet from the home list is only honest while auto-sweep is
/// emptying it. A wallet that accumulates funds must stay visible, or its
/// balance vanishes from the only list its owner counts — so auto-sweep gates
/// hide-on-home: turning sweeping off unhides the wallet, and hiding is refused
/// while sweeping is off. Unhiding is always allowed.
///
/// This is applied at the write itself ([WalletRepository.updateWalletBehavior])
/// and to the optimistic UI update, so no screen — present or future — can
/// persist or display the forbidden combination.
({bool hideOnHome, bool autoSweepEnabled}) resolveWalletBehaviorChange({
  required bool hideOnHome,
  required bool autoSweepEnabled,
  bool? requestedHideOnHome,
  bool? requestedAutoSweepEnabled,
}) {
  final sweeps = requestedAutoSweepEnabled ?? autoSweepEnabled;
  final hides = requestedHideOnHome ?? hideOnHome;
  return (hideOnHome: sweeps && hides, autoSweepEnabled: sweeps);
}
