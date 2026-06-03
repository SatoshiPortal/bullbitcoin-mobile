import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract class AutosweepWalletPort {
  Future<Wallet?> getDefaultWallet({
    required Wallet sourceWallet,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  });

  Future<String> getCurrentReceiveAddress({required String walletId});

  Future<String> buildLiquidDrainPset({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
  });

  Future<String> signLiquidPset({
    required String pset,
    required String walletId,
  });

  Future<String> buildBitcoinDrainPsbt({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
  });

  Future<int> getBitcoinFeeSat({required String psbt});

  Future<String> signBitcoinPsbt({
    required String psbt,
    required String walletId,
  });
}
