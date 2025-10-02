import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract class WalletPort {
  Future<Wallet?> getWallet(String walletId);
  //Future<List<Wallet>> getAllWallets();
  //Future<void> getDefaultWallets();
}
