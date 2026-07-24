import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/await_cbf_sync_inactive_usecase.dart';

/// Resolves the wallet's already-revealed (or brand-new) receive address.
///
/// [WalletAddressRepository.generateNewReceiveAddress] and
/// [WalletAddressRepository.getLastRevealedReceiveAddress] can both reveal a
/// new script — the latter whenever the wallet has no revealed address yet
/// — by loading, mutating, and persisting the underlying BDK wallet handle.
/// A wallet synced through compact block filters can have its own native
/// session (`CbfWalletDatasource`) independently loading and persisting
/// that very same handle for the whole span of its scan
/// (`CbfWalletDatasource._run`), so this usecase never touches that
/// session: it waits for any active attempt to settle on its own — never
/// requesting its cancellation — before either address method runs. A
/// wallet with no active attempt (the common case) pays no waiting cost at
/// all; see [AwaitCbfSyncInactiveUsecase].
class GetReceiveAddressUsecase {
  final WalletAddressRepository _walletAddressRepository;
  final AwaitCbfSyncInactiveUsecase _awaitCbfSyncInactive;

  GetReceiveAddressUsecase({
    required this._walletAddressRepository,
    required AwaitCbfSyncInactiveUsecase awaitCbfSyncInactiveUsecase,
  }) : _awaitCbfSyncInactive = awaitCbfSyncInactiveUsecase;

  Future<WalletAddress> execute({
    required String walletId,
    bool generateNew = false,
  }) async {
    // Waits, never cancels: a live CBF session may still be loading and
    // persisting this wallet's BDK handle. Resolves immediately for a
    // Liquid wallet, an Electrum-backed wallet, or a Bitcoin/CBF wallet
    // with no attempt currently running.
    await _awaitCbfSyncInactive.execute(walletId: walletId);

    try {
      final address = generateNew
          ? await _walletAddressRepository.generateNewReceiveAddress(
              walletId: walletId,
            )
          : await _walletAddressRepository.getLastRevealedReceiveAddress(
              walletId: walletId,
            );

      return address;
    } catch (e) {
      throw GetReceiveAddressException(e.toString());
    }
  }
}

class GetReceiveAddressException extends BullException {
  GetReceiveAddressException(super.message);
}
