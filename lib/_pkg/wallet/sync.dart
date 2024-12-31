import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sync.dart';
import 'package:bb_mobile/_repository/wallet/internal_network.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/locator.dart';

class WalletSync implements IWalletSync {
  WalletSync({
    required InternalWalletsRepository walletsRepository,
    required InternalNetworkRepository networkRepository,
    required BDKSync bdkSync,
    required LWKSync lwkSync,
  })  : _walletsRepository = walletsRepository,
        _networkRepository = networkRepository,
        _bdkSync = bdkSync,
        _lwkSync = lwkSync;

  final InternalWalletsRepository _walletsRepository;
  final InternalNetworkRepository _networkRepository;
  final BDKSync _bdkSync;
  final LWKSync _lwkSync;

  @override
  Future<Err?> syncWallet(Wallet wallet) async {
    try {
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (blockchain, errNetwork) = _networkRepository.bdkBlockchain;
          if (errNetwork != null) throw errNetwork;
          final (bdkWallet, errWallet) =
              _walletsRepository.getBdkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final (updatedBdkWallet, errSyncing) = await _bdkSync.syncWalletOld(
            bdkWallet: bdkWallet!,
            blockChain: blockchain!,
          );
          if (errSyncing != null) throw errSyncing;
          final err =
              _walletsRepository.updateBdkWallet(wallet, updatedBdkWallet!);
          if (err != null) throw err;
        case BaseWalletType.Liquid:
          final (blockchain, errNetwork) = _networkRepository.liquidUrl;
          if (errNetwork != null) throw errNetwork;
          final (liqWallet, errWallet) =
              _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final (updatedLiqWallet, errSyncing) =
              await _lwkSync.syncLiquidWalletOld(
            lwkWallet: liqWallet!,
            blockChain: blockchain!,
          );
          if (errSyncing != null) {
            if (errSyncing.message.contains(
              'LwkError(msg: UpdateHeightTooOld { update_tip_height: ',
            )) {
              locator
                  .get<WalletsStorageRepository>()
                  .deleteWalletFile(wallet.id);
              // create db file or restart app
            }
            if (errSyncing.message.contains(
              'LwkError(msg: UpdateOnDifferentStatus { wollet_status: ',
            )) {
              locator
                  .get<WalletsStorageRepository>()
                  .deleteWalletFile(wallet.id);
              // create db file or restart app
            }
            throw errSyncing;
          }
          final err =
              _walletsRepository.updateLwkWallet(wallet, updatedLiqWallet!);
          if (err != null) throw err;
      }
    } catch (e) {
      final isLiq = wallet.isLiquid() ? 'Liquid' : 'Secure/Bitcoin';
      final fngr = wallet.sourceFingerprint;
      return Err(
        e.toString(),
        title: 'Error occurred while syncing $isLiq wallet - $fngr.',
        solution: 'Please try again.',
        printToConsole: true,
      );
    }
    return null;
  }

  @override
  void cancelSync() {
    _bdkSync.cancelSync();
    _lwkSync.cancelSync();
  }
}
