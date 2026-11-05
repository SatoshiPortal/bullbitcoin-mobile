import 'package:primitives/primitives.dart' show BullException;
import 'package:primitives/primitives.dart' show RelativeFee;
import 'package:wallet/wallet.dart';

class PrepareLiquidSendUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  PrepareLiquidSendUsecase({required this._liquidWalletRepository});

  Future<String> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw Exception('Amount cannot be empty if drain is not true');
      }

      final psbt = await _liquidWalletRepository.buildPset(
        walletId: walletId,
        address: address,
        amountSat: drain ? null : amountSat,
        feeRate: feeRate,
        drain: drain,
      );
      return psbt;
    } on NoSpendableUtxoException {
      rethrow;
    } on ConsolidationRequiredException {
      rethrow;
    } on InsufficientFundsException {
      rethrow;
    } catch (e) {
      throw PrepareLiquidSendException(e.toString());
    }
  }
}

class PrepareLiquidSendException extends BullException {
  PrepareLiquidSendException(super.message);
}
