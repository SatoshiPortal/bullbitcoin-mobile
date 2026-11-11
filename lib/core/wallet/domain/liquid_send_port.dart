import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

abstract interface class LiquidSendPort {
  @useResult
  Future<Result<String, WalletFailure>> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
    Set<Outpoint>? selectedInputs,
  });
}
