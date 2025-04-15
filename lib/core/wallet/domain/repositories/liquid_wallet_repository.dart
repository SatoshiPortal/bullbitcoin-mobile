import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

abstract class LiquidWalletRepository {
  Future<String> buildPset({
    required String origin,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
  });
  Future<Uint8List> signPset({
    required String pset,
    required String origin,
  });
}
