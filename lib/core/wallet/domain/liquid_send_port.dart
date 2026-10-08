import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';

abstract interface class LiquidSendPort {
  Future<String> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
    Set<Outpoint>? selectedInputs,
  });
}
