import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';

class PrepareLiquidSendUsecase {
  final LiquidWalletRepository _liquidWalletRepository;

  PrepareLiquidSendUsecase({
    required LiquidWalletRepository liquidWalletRepository,
  }) : _liquidWalletRepository = liquidWalletRepository;

  Future<String> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
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
        networkFee: networkFee,
        drain: drain,
      );
      return psbt;
    } on NoSpendableUtxoException {
      rethrow;
    } catch (e) {
      throw PrepareLiquidSendException(e.toString());
    }
  }
}

class PrepareLiquidSendException extends BullException {
  PrepareLiquidSendException(super.message);
}
