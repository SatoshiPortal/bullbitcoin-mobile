import 'dart:typed_data';

abstract class BitcoinWalletRepository {
  Future<bool> isMine(Uint8List scriptBytes);
  Future<String> signPsbt(String psbt);
}
