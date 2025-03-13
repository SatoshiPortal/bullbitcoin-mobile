import 'dart:typed_data';

abstract class BitcoinWalletRepository {
  Future<bool> isMine(Uint8List scriptBytes);
  Future<String> buildPsbt({
    required String address,
    required BigInt amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
  });
  Future<String> signPsbt(String psbt);
}
