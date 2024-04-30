import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sync.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';

class WalletSync implements IWalletSync {
  WalletSync({
    required WalletsRepository walletsRepository,
    required NetworkRepository networkRepository,
    required BDKSync bdkSync,
    required LWKSync lwkSync,
  })  : _walletsRepository = walletsRepository,
        _networkRepository = networkRepository,
        _bdkSync = bdkSync,
        _lwkSync = lwkSync;

  final WalletsRepository _walletsRepository;
  final NetworkRepository _networkRepository;
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
          if (errSyncing != null) throw errSyncing;
          final err =
              _walletsRepository.updateLwkWallet(wallet, updatedLiqWallet!);
          if (err != null) throw err;
      }
    } catch (e) {
      return Err(
        e.toString(),
        title: 'Error occurred while syncing wallet',
        solution: 'Please try again.',
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
