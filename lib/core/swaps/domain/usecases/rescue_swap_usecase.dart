import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Rebuilds an orphaned restored swap into local storage + the watcher, sending
/// funds to the [selectedWalletId] the user picked (on the swap's acting chain).
class RescueSwapUsecase {
  final BoltzSwapRepository _swapRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;

  RescueSwapUsecase({
    required this._swapRepository,
    required this._settingsRepository,
    required this._walletRepository,
  });

  Future<Swap> execute({
    required RestoredSwap restored,
    required String selectedWalletId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final btcElectrumUrl = isTestnet
          ? ApiServiceConstants.publicElectrumTestUrl
          : ApiServiceConstants.bbElectrumUrl;
      final lbtcElectrumUrl = isTestnet
          ? ApiServiceConstants.publicliquidElectrumTestUrlPath
          : ApiServiceConstants.bbLiquidElectrumUrlPath;

      // Map the user-selected wallet (on the acting chain) to the swap's
      // send/receive roles; for chain swaps the opposite role falls back to the
      // default wallet of the other chain (required, but unused on the happy path).
      final defaults = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );
      String? defaultIdForAsset(String asset) {
        final wantLiquid = asset == 'L-BTC';
        for (final w in defaults) {
          if (w.isLiquid == wantLiquid) return w.id;
        }
        return null;
      }

      String sendWalletId;
      String? receiveWalletId;
      switch (restored.kind) {
        case RestoredSwapKind.lightningReceive:
          receiveWalletId = selectedWalletId;
          sendWalletId = selectedWalletId; // unused for reverse swaps
        case RestoredSwapKind.lightningSend:
          sendWalletId = selectedWalletId;
          receiveWalletId = null;
        case RestoredSwapKind.crossChain:
          if (restored.isRefundAction) {
            sendWalletId = selectedWalletId;
            receiveWalletId = defaultIdForAsset(restored.toAsset);
          } else {
            receiveWalletId = selectedWalletId;
            sendWalletId =
                defaultIdForAsset(restored.fromAsset) ?? selectedWalletId;
          }
      }

      log.info(
        'SWAP_RESTORE: rescuing ${restored.id} (${restored.kind.name}) '
        'send=$sendWalletId receive=$receiveWalletId',
      );
      return await _swapRepository.rescueSwap(
        restored: restored,
        sendWalletId: sendWalletId,
        receiveWalletId: receiveWalletId,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
      );
    } catch (e) {
      log.warning('SWAP_RESTORE: rescue failed: $e');
      throw RescueSwapException('$e');
    }
  }

  /// Wallets the user can pick to receive the rescued funds — those on the
  /// chain this swap acts on (claim destination or refund return).
  Future<List<Wallet>> candidateWallets(RestoredSwap restored) async {
    final settings = await _settingsRepository.fetch();
    return _walletRepository.getWallets(
      onlyBitcoin: !restored.actsOnLiquid,
      onlyLiquid: restored.actsOnLiquid,
      environment: settings.environment,
    );
  }
}

class RescueSwapException extends BullException {
  RescueSwapException(super.message);
}
