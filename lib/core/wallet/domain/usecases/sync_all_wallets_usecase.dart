import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';

class SyncAllWalletsUsecase {
  final WalletManagerService _walletManagerService;

  const SyncAllWalletsUsecase({
    required WalletManagerService walletManagerService,
  }) : _walletManagerService = walletManagerService;

  Future<List<Wallet>> execute({
    Environment? environment,
  }) async {
    debugPrint('Starting to sync all wallets and reinitialize swap watcher');
    final syncedWallets = await _walletManagerService.syncAll(
      environment: environment,
    );

    debugPrint('Successfully synced ${syncedWallets.length} wallets');
    return syncedWallets;
  }
}
