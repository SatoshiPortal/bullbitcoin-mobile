/// Shell destinations used by RecoverBull, independent of route names.
abstract interface class RecoverBullNavigationPort {
  void openTorSettings();

  void openWalletHome();
}

/// The application shell binds these actions to its own router.
final class RecoverBullNavigationCallbacks
    implements RecoverBullNavigationPort {
  final void Function() onOpenTorSettings;
  final void Function() onOpenWalletHome;

  const RecoverBullNavigationCallbacks({
    required this.onOpenTorSettings,
    required this.onOpenWalletHome,
  });

  @override
  void openTorSettings() => onOpenTorSettings();

  @override
  void openWalletHome() => onOpenWalletHome();
}
