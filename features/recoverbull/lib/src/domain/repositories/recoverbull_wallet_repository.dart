import '../entities/recoverbull_network.dart';
import '../entities/recoverbull_wallet.dart';

abstract interface class RecoverBullWalletRepository {
  Future<List<RecoverBullWallet>> getWallets({
    bool onlyBitcoin = false,
    bool onlyDefaults = false,
    RecoverBullNetwork? network,
  });
}
