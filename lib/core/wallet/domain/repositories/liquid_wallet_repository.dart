import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

abstract class LiquidWalletRepository {
  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
  });
  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset});
  Future<String> signPset({required String pset, required String walletId});
}
