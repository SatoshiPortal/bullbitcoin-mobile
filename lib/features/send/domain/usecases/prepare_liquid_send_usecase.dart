import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';

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
    } catch (e) {
      throw PrepareLiquidSendException(e.toString());
    }
  }
}

class PrepareLiquidSendException extends BullException {
  PrepareLiquidSendException(super.message);
}
