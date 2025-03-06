import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/create.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';

class WalletCreate implements IWalletCreate {
  WalletCreate({
    required InternalWalletsRepository walletsRepository,
    required LWKCreate lwkCreate,
    required BDKCreate bdkCreate,
    required WalletsStorageRepository walletsStorageRepository,
  })  : _walletsRepository = walletsRepository,
        _lwkCreate = lwkCreate,
        _bdkCreate = bdkCreate,
        _walletsStorageRepository = walletsStorageRepository;

  final InternalWalletsRepository _walletsRepository;
  final WalletsStorageRepository _walletsStorageRepository;

  final LWKCreate _lwkCreate;
  final BDKCreate _bdkCreate;

  @override
  Future<(Wallet?, Err?)> loadPublicWallet({
    required String saveDir,
    Wallet? wallet,
    required BBNetwork network,
  }) async {
    try {
      Wallet w;
      if (wallet == null) {
        final (walletFromStorage, err) =
            await _walletsStorageRepository.readWallet(
          walletHashId: saveDir,
        );
        if (err != null) return (null, err);
        w = walletFromStorage!;
      } else {
        w = wallet;
      }

      if (w.network != network) throw 'Network mismatch';

      switch (w.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (_, errWallet) =
              _walletsRepository.getBdkWallet(w.id, errExpected: true);
          if (errWallet == null) {
            return (w, null);
          }
          final (bdkWallet, errLoading) =
              await _bdkCreate.loadPublicBdkWallet(w);
          if (errLoading != null) throw errLoading;
          final errSave = _walletsRepository.setBdkWallet(w.id, bdkWallet!);
          if (errSave != null) {
            throw errSave;
          }
          return (w, null);

        case BaseWalletType.Liquid:
          final (_, errWallet) =
              _walletsRepository.getLwkWallet(w.id, errExpected: true);
          if (errWallet == null) return (w, null);
          final (liqWallet, errLoading) =
              await _lwkCreate.loadPublicLwkWallet(w);
          if (errLoading != null) throw errLoading;
          final errSave = _walletsRepository.setLwkWallet(w.id, liqWallet!);
          if (errSave != null) throw errSave;

          return (w, null);
      }
    } catch (e) {
      // print('Error: $e');
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while creating wallet',
          solution: 'Please try again.',
        )
      );
    }
  }
}
