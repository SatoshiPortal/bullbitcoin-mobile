import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/swap_network_policy.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

import 'package:bb_mobile/core/utils/result.dart';

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

  Future<Result<Swap, SwapFailure>> execute({
    required RestoredSwap restored,
    required String selectedWalletId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (!swapEnvironmentAvailable(settings.environment.networkEnv)) {
        log.config(
          'Swap recovery unavailable network=${settings.environment.name}',
        );
        return const Err(SwapUnsupportedNetworkFailure());
      }
      final selected = await _walletRepository.getWallet(selectedWalletId);
      switch (selected) {
        case Err():
          return const Err(SwapInvalidStateFailure());
        case Ok(:final value):
          if (value.network.environment != settings.environment.networkEnv ||
              value.isLiquid != restored.actsOnLiquid) {
            return const Err(SwapUnsupportedNetworkFailure());
          }
      }
      final isTestnet = settings.environment.networkEnv == NetworkEnv.testnet;

      final btcElectrumUrl = isTestnet
          ? ApiServiceConstants.publicElectrumTestUrl
          : ApiServiceConstants.bbElectrumUrl;
      final lbtcElectrumUrl = isTestnet
          ? ApiServiceConstants.publicliquidElectrumTestUrlPath
          : ApiServiceConstants.bbLiquidElectrumUrlPath;

      // Map the user-selected wallet (on the acting chain) to the swap's
      // send/receive roles; for chain swaps the opposite role falls back to the
      // default wallet of the other chain (required, but unused on the happy path).
      final defaults = switch (await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw RescueSwapException(
          'wallets read failed: ${failure.runtimeType}',
        ),
      };
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
            // A refund has no claim/receive side; don't associate a
            // destination-chain wallet.
            sendWalletId = selectedWalletId;
            receiveWalletId = null;
          } else {
            receiveWalletId = selectedWalletId;
            sendWalletId =
                defaultIdForAsset(restored.fromAsset) ??
                (throw RescueSwapException(
                  'no default ${restored.fromAsset} wallet to receive a refund',
                ));
          }
      }

      log.fine('Swap rescue started network=${settings.environment.name}');
      return Ok(
        await _swapRepository.rescueSwap(
          restored: restored,
          sendWalletId: sendWalletId,
          receiveWalletId: receiveWalletId,
          btcElectrumUrl: btcElectrumUrl,
          lbtcElectrumUrl: lbtcElectrumUrl,
        ),
      );
    } on String {
      // The legacy provider still throws strings; contain them without
      // logging their payload or swallowing programmer Errors.
      return const Err(SwapUnexpectedFailure());
    } on Exception {
      log.warning('Swap rescue unavailable');
      return const Err(SwapUnexpectedFailure());
    }
  }

  /// Wallets the user can pick to receive the rescued funds — those on the
  /// chain this swap acts on (claim destination or refund return).
  Future<Result<List<Wallet>, SwapFailure>> candidateWallets(
    RestoredSwap restored,
  ) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (!swapEnvironmentAvailable(settings.environment.networkEnv)) {
        log.config(
          'Swap recovery unavailable network=${settings.environment.name}',
        );
        return const Err(SwapUnsupportedNetworkFailure());
      }
      return (await _walletRepository.getWallets(
        onlyBitcoin: !restored.actsOnLiquid,
        onlyLiquid: restored.actsOnLiquid,
        environment: settings.environment,
      )).mapErr((_) => const SwapUnexpectedFailure());
    } on Exception {
      return const Err(SwapUnexpectedFailure());
    }
  }
}

class RescueSwapException extends BullException {
  RescueSwapException(super.message);
}
