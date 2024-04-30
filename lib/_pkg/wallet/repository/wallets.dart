import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class WalletsRepository {
  final Set<({String id, bdk.Wallet wallet})> _bdkWallets = {};
  final Set<({String id, lwk.Wallet wallet})> _lwkWallets = {};

  (bdk.Wallet?, Err?) getBdkWallet(String id, {bool errExpected = false}) {
    for (final bdkWallet in _bdkWallets)
      if (bdkWallet.id == id) {
        return (bdkWallet.wallet, null);
      }
    return (null, Err('Wallet not found', expected: errExpected));
  }

  (lwk.Wallet?, Err?) getLwkWallet(String id, {bool errExpected = false}) {
    for (final lwkWallet in _lwkWallets)
      if (lwkWallet.id == id) return (lwkWallet.wallet, null);

    return (null, Err('Wallet not found', expected: errExpected));
  }

  Err? setLwkWallet(Wallet wallet, lwk.Wallet lwkWallet) {
    final added = _lwkWallets.add((id: wallet.id, wallet: lwkWallet));
    if (!added) return Err('Wallet already exists');
    return null;
  }

  Err? setBdkWallet(Wallet wallet, bdk.Wallet bdkWallet) {
    final added = _bdkWallets.add((id: wallet.id, wallet: bdkWallet));
    if (!added) return Err('Wallet already exists');
    return null;
  }

  Err? removeLwkWallet(Wallet wallet) {
    final exits = _lwkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    _lwkWallets.removeWhere((element) => element.id == wallet.id);
    return null;
  }

  Err? removeBdkWallet(Wallet wallet) {
    final exits = _bdkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    _bdkWallets.removeWhere((element) => element.id == wallet.id);
    return null;
  }

  Err? removeWallet(Wallet wallet) {
    try {
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          return removeBdkWallet(wallet);
        case BaseWalletType.Liquid:
          return removeLwkWallet(wallet);
      }
    } catch (e) {
      return Err(e.toString());
    }
  }

  Err? replaceBdkWallet(Wallet wallet, bdk.Wallet bdkWallet) {
    final exits = _bdkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    _bdkWallets.removeWhere((element) => element.id == wallet.id);
    _bdkWallets.add((id: wallet.id, wallet: bdkWallet));
    return null;
  }

  Err? replaceLwkWallet(Wallet wallet, lwk.Wallet lwkWallet) {
    final exits = _lwkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    _lwkWallets.removeWhere((element) => element.id == wallet.id);
    _lwkWallets.add((id: wallet.id, wallet: lwkWallet));
    return null;
  }
}
