import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../entities/recoverbull_network.dart';
import '../entities/recoverbull_wallet.dart';

abstract interface class RecoverBullWalletRepository {
  Future<Result<List<RecoverBullWallet>, RecoverBullFailure>> getWallets({
    bool onlyBitcoin = false,
    bool onlyDefaults = false,
    RecoverBullNetwork? network,
  });
}
