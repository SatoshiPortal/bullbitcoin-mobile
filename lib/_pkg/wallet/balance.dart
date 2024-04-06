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
          final (bdkWallet, errWallet) = _walletsRepository.getBdkWallet(wallet);
          if (errWallet != null) throw errWallet;
          return await _bdkBalance.getBalance(bdkWallet: bdkWallet!, wallet: wallet);

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) = _walletsRepository.getLwkWallet(wallet);
          if (errWallet != null) throw errWallet;
          return await _lwkBalance.getLiquidBalance(lwkWallet: liqWallet!, wallet: wallet);
        case BaseWalletType.Lightning:
          throw 'Not implemented';
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

// class WalletBalance {
//   Future<((Wallet, Balance)?, Err?)> getBalance({
//     required bdk.Wallet bdkWallet,
//     required Wallet wallet,
//   }) async {
//     try {
//       final bdkbalance = await bdkWallet.getBalance();

//       final balance = Balance(
//         confirmed: bdkbalance.confirmed,
//         untrustedPending: bdkbalance.untrustedPending,
//         immature: bdkbalance.immature,
//         trustedPending: bdkbalance.trustedPending,
//         spendable: bdkbalance.spendable,
//         total: bdkbalance.total,
//       );

//       final w = wallet.copyWith(balance: balance.total, fullBalance: balance);

//       return ((w, balance), null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while getting balance',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }

//   Future<((Wallet, Balance)?, Err?)> getLiquidBalance({
//     required lwk.Wallet lwkWallet,
//     required Wallet wallet,
//   }) async {
//     try {
//       final assetToPick = wallet.network == BBNetwork.LMainnet ? lwk.lBtcAssetId : lwk.lTestAssetId;
//       final balances = await lwkWallet.balance();
//       final finalBalance = balances.where((e) => e.$1 == assetToPick).map((e) => e.$2).first;

//       final balance = Balance(
//         confirmed: finalBalance,
//         untrustedPending: 0,
//         immature: 0,
//         trustedPending: 0,
//         spendable: finalBalance,
//         total: finalBalance,
//       );

//       final w = wallet.copyWith(balance: balance.total, fullBalance: balance);

//       return ((w, balance), null);
//     } on Exception catch (e) {
//       return (
//         null,
//         Err(
//           e.message,
//           title: 'Error occurred while getting balance',
//           solution: 'Please try again.',
//         )
//       );
//     }
//   }
// }
