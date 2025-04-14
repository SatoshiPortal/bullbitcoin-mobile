import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';

abstract class BitcoinWalletRepository {
  Future<String> buildPsbt({
    required String origin,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<Utxo>? unspendable,
    List<Utxo>? selected,
    bool? replaceByFee,
  });
  Future<String> signPsbt(
    String psbt, {
    required String origin,
  });
  Future<bool> isScriptOfWallet({
    required String origin,
    required Uint8List script,
  });
}
