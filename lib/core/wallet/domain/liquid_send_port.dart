import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

abstract interface class LiquidSendPort {
  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
  });
}
