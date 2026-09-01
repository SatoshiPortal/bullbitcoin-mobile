import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';

/// Clears private signing material, and records whether doing so owes the user
/// a return to the locked Passphrase page.
///
/// [forBackground] is the app lifecycle's intent: the app took the wallet away
/// while the user was elsewhere, so the next resume navigates them back
/// (decision 5). [atUserRequest] is the same clearing without that debt — the
/// user asked for it and is already looking at the page they chose.
///
/// Clearing is immediate in both cases; only the navigation differs.
final class LockPrivateWalletSessionUsecase {
  final WalletSigningMaterialResolver _resolver;

  const LockPrivateWalletSessionUsecase(this._resolver);

  bool forBackground() => _resolver.clearPrivateCapabilityForBackground();

  bool atUserRequest() => _resolver.clearPrivateCapability();

  bool takePendingNavigationRequest() =>
      _resolver.takePendingLockNavigationRequest();
}
