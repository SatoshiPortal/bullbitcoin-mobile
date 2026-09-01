export 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart'
    show
        WalletDefinition,
        WalletDefinitionRestoreResult,
        WalletDefinitionRestoreStatus;

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_private_wallet_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_public_projection_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/lock_private_wallet_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/mount_wallet_with_private_capability_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_label_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_visible_wallet_catalog_usecase.dart';

/// The one entry point into the wallet feature for everything outside it.
///
/// It exposes user intents and the visible catalog. The private signing-material
/// session and the resolver that reads it stay inside `lib/core/wallet`: no
/// seed, no session object and no signing material crosses this boundary, in
/// either direction except the one place ownership is deliberately handed over
/// — [mountPassphraseWallet] (spec F13, 13.5).
class WalletFacade {
  final MountWalletWithPrivateCapabilityUsecase _mount;
  final LockPrivateWalletSessionUsecase _lock;
  final CheckPrivateWalletSessionUsecase _checkSession;
  final WatchVisibleWalletCatalogUsecase _watchVisibleCatalog;
  final DeleteWalletPublicProjectionUsecase _deleteProjection;
  final UpdateWalletLabelUsecase _updateLabel;

  const WalletFacade(
    this._mount,
    this._lock,
    this._checkSession,
    this._watchVisibleCatalog,
    this._deleteProjection,
    this._updateLabel,
  );

  int beginPassphraseWalletMount() => _mount.begin();

  void cancelPassphraseWalletMount() => _mount.cancel();

  /// Mounts [definition]'s public projection and transfers ownership of [seed]
  /// to the wallet's private session, replacing whatever was loaded before —
  /// only one wallet holds a private capability at a time.
  ///
  /// The seed travels in and is never readable back out.
  Future<({WalletDefinitionRestoreResult result, bool capabilityLoaded})>
  mountPassphraseWallet({
    required WalletDefinition definition,
    required MnemonicSeed seed,
    required int mountGeneration,
    String? label,
  }) => _mount.execute(
    definition: definition,
    seed: seed,
    mountGeneration: mountGeneration,
    label: label,
  );

  /// Clears the loaded private signing material immediately because the app is
  /// leaving the foreground. Returns whether anything was loaded.
  ///
  /// The app lifecycle owner is the only caller; the return-to-Passphrase
  /// request it creates is collected on the next resume with
  /// [takePendingLockNavigationRequest] (decision 5).
  bool lockPrivateWalletSession() => _lock.forBackground();

  /// Clears the loaded private signing material at the user's own request —
  /// switching passphrase wallets, or forgetting one — and asks for no
  /// navigation.
  bool unloadPrivateWalletSession() => _lock.atUserRequest();

  /// Whether the last background lock owes the user a return to the locked
  /// Passphrase page. True at most once per lock.
  bool takePendingLockNavigationRequest() =>
      _lock.takePendingNavigationRequest();

  /// Whether [walletId] currently holds the private capability.
  bool isPrivateWalletSessionLoaded(String walletId) =>
      _checkSession.isLoaded(walletId);

  /// The wallets Home may show, republished whenever a private capability is
  /// loaded or cleared. A locked passphrase wallet is absent from it.
  Stream<List<Wallet>> watchVisibleWalletCatalog() =>
      _watchVisibleCatalog.execute();

  /// Deletes the wallet's locally cached public projection, clearing its
  /// private capability first if it holds one.
  Future<void> deletePublicProjection(String walletId) =>
      _deleteProjection.execute(walletId);

  /// Updates the label the wallet shows while mounted.
  Future<void> updateWalletLabel({
    required String walletId,
    required String label,
  }) => _updateLabel.execute(walletId: walletId, label: label);
}
