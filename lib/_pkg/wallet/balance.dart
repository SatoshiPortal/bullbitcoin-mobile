import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/balance.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/balance.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';

class WalletBalance implements IWalletBalance {
  WalletBalance({
    required WalletsRepository walletsRepository,
    required BDKBalance bdkBalance,
    required LWKBalance lwkBalance,
  })  : _walletsRepository = walletsRepository,
        _bdkBalance = bdkBalance,
        _lwkBalance = lwkBalance;

  final WalletsRepository _walletsRepository;
  final BDKBalance _bdkBalance;
  final LWKBalance _lwkBalance;

  @override
  Future<((Wallet, Balance)?, Err?)> getBalance(Wallet wallet) async {
    try {
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (bdkWallet, errWallet) =
              _walletsRepository.getBdkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          return await _bdkBalance.getBalance(
            bdkWallet: bdkWallet!,
            wallet: wallet,
          );

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) =
              _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          return await _lwkBalance.getLiquidBalance(
            lwkWallet: liqWallet!,
            wallet: wallet,
          );
      }
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while getting balance',
          solution: 'Please try again.',
        )
      );
    }
  }
}
