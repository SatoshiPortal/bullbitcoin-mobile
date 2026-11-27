import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'wallet_details_failure.dart';

/// Deletes one non-default wallet, fail-closed: every check that cannot
/// prove the deletion safe refuses it, and the seed is trashed only once no
/// remaining wallet, in any view or owner, references it.
class DeleteWalletUsecase {
  final SecretsInventory _inventory;
  final WalletNativeLifecycle _native;
  final SwapStore _swaps;
  final OrderSwaps _orders;
  final SeedReferences _references;
  final Secrets _secrets;

  const DeleteWalletUsecase({
    required this._inventory,
    required this._native,
    required this._swaps,
    required this._orders,
    required this._references,
    required this._secrets,
  });

  @useResult
  Future<Result<void, WalletDetailsFailure>> execute(String walletId) async {
    // An Exchange order in flight would be stranded with its wallet.
    switch (await _orders.getPendingOrders()) {
      case Ok(:final value)
          when value.any(
            (order) =>
                order.sourceWalletId == walletId ||
                order.destinationWalletId == walletId,
          ):
        return const Err(WalletDetailsOngoingSwapsFailure());
      case Err(:final failure):
        return Err(
          WalletDetailsUnavailableFailure(
            'pending order check: ${failure.runtimeType}',
          ),
        );
      case Ok():
    }

    final WalletRegistration wallet;
    switch (await _inventory.readWallet(walletId)) {
      case Ok(:final value):
        wallet = value;
      case Err(failure: WalletRegistrationNotFoundFailure()):
        return const Err(WalletDetailsNotFoundFailure());
      case Err(:final failure):
        return Err(WalletDetailsUnavailableFailure('${failure.runtimeType}'));
    }
    if (wallet.isDefault) return const Err(WalletDetailsDefaultFailure());

    switch (await _swaps.ongoing(walletId: walletId)) {
      case Ok(:final value) when value.isNotEmpty:
        return const Err(WalletDetailsOngoingSwapsFailure());
      case Err(:final failure):
        log.warning('Wallet delete failed stage=swap reason=storage');
        return Err(
          WalletDetailsUnavailableFailure(
            'ongoing swap check: ${failure.runtimeType}',
          ),
        );
      case Ok():
    }

    final key = WalletKey(id: wallet.id, network: wallet.network);
    if (await _native.delete(key) case Err(:final failure)) {
      return Err(WalletDetailsUnavailableFailure('native: ${failure.logCode}'));
    }
    if (await _inventory.removeWallet(walletId) case Err()) {
      log.severe(
        message: 'Wallet delete failed reason=storage',
        error: 'storage',
        trace: StackTrace.empty,
      );
      return const Err(WalletDetailsUnavailableFailure('inventory'));
    }
    if (await _native.catalogDeleted(key) case Err(:final failure)) {
      return Err(
        WalletDetailsUnavailableFailure('catalog: ${failure.logCode}'),
      );
    }
    log.fine('Wallet deleted outcome=ok');

    // Bitcoin and Liquid default wallets share a seed, so it goes only with
    // the last locally signing wallet derived from it (#2324). A watch-only
    // origin never holds or keeps a seed (#2634).
    final fingerprint = wallet.secretFingerprint;
    if (wallet.signer == WalletSigner.local && fingerprint != null) {
      await _deleteOrphanSeed(fingerprint);
    }
    return const Ok(null);
  }

  /// Best effort: a failure leaves an orphan seed entry but never fails the
  /// deletion the user asked for. A seed without a tested backup stays too:
  /// keeping key material is recoverable, deleting it is not, and its
  /// membership still needs a proof before the view can take a PIN.
  Future<void> _deleteOrphanSeed(Fingerprint fingerprint) async {
    switch (await _references.deleteUnreferenced(_secrets, fingerprint)) {
      case Ok():
        log.fine('Seed deleted source=wallet_cleanup');
      case Err(failure: ParentCustodyReferencedFailure()):
        log.fine('Seed cleanup skipped reason=referenced');
      case Err(failure: ParentCustodyBackupRequiredFailure()):
        log.warning('Seed cleanup refused reason=backup_required');
      case Err(failure: ParentCustodyBackupUnavailableFailure()):
        log.warning('Seed cleanup refused reason=backup_unavailable');
      case Err(failure: ParentCustodyStateFailure()):
        log.warning('Seed cleanup refused reason=custody_state');
      case Err(failure: ParentCustodyMetadataFailure()):
        log.warning('Seed cleanup refused reason=custody_metadata');
      case Err():
        log.warning('Seed cleanup failed reason=references_unavailable');
    }
  }
}
