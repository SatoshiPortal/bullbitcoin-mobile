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

  Err? setLwkWallet(String id, lwk.Wallet lwkWallet) {
    final added = _lwkWallets.add((id: id, wallet: lwkWallet));
    if (!added) return Err('Wallet already exists');
    return null;
  }

  Err? setBdkWallet(String id, bdk.Wallet bdkWallet) {
    final added = _bdkWallets.add((id: id, wallet: bdkWallet));
    if (!added) return Err('Wallet already exists');
    return null;
  }

  Err? removeLwkWallet(String id) {
    final exits = _lwkWallets.any((element) => element.id == id);
    if (!exits) return Err('Wallet does not exist');
    _lwkWallets.removeWhere((element) => element.id == id);
    return null;
  }

  Err? removeBdkWallet(String id) {
    final exits = _bdkWallets.any((element) => element.id == id);
    if (!exits) return Err('Wallet does not exist');
    _bdkWallets.removeWhere((element) => element.id == id);
    return null;
  }

  Err? removeWallet(BaseWalletType baseWalletType, String id) {
    try {
      switch (baseWalletType) {
        case BaseWalletType.Bitcoin:
          return removeBdkWallet(id);
        case BaseWalletType.Liquid:
          return removeLwkWallet(id);
      }
    } catch (e) {
      return Err(e.toString());
    }
  }

  Err? updateBdkWallet(Wallet wallet, bdk.Wallet bdkWallet) {
    final exits = _bdkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    _bdkWallets.removeWhere((element) => element.id == wallet.id);
    _bdkWallets.add((id: wallet.id, wallet: bdkWallet));
    return null;
  }

  Err? updateLwkWallet(Wallet wallet, lwk.Wallet lwkWallet) {
    final exits = _lwkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    _lwkWallets.removeWhere((element) => element.id == wallet.id);
    _lwkWallets.add((id: wallet.id, wallet: lwkWallet));
    return null;
  }
}
