import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';

class SyncAllWalletsUsecase {
  final WalletManagerService _walletManagerService;
  final SwapWatcherService? _swapWatcherService;

  const SyncAllWalletsUsecase({
    required WalletManagerService walletManagerService,
    required SwapWatcherService swapWatcherService,
  })  : _walletManagerService = walletManagerService,
        _swapWatcherService = swapWatcherService;

  Future<List<Wallet>> execute({
    Environment? environment,
  }) async {
    debugPrint('Starting to sync all wallets and reinitialize swap watcher');
    final syncedWallets = await _walletManagerService.syncAll(
      environment: environment,
    );

    if (_swapWatcherService != null) {
      try {
        await _swapWatcherService.restartWatcherWithOngoingSwaps();
      } catch (e) {
        debugPrint('Error restarting swap watcher: $e');
      }
    }

    debugPrint('Successfully synced ${syncedWallets.length} wallets');
    return syncedWallets;
  }
}
