import 'package:bb_mobile/_core/data/repositories/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';

class BuildPsbtUseCase {
  final PayjoinRepository _payjoin;
  final WalletManagerService _walletManager;

  BuildPsbtUseCase({
    required PayjoinRepository payjoin,
    required WalletManagerService walletManager,
  })  : _payjoin = payjoin,
        _walletManager = walletManager;

  Future<String> execute({
    required String walletId,
    required String address,
    BigInt? amountSat,
    double? feeRateSatPerVb,
    bool? drain,
    bool? ignoreUnspendableInputs,
  }) async {
    try {
      // Inputs that are already used in ongoing payjoin sessions should not be
      //  used in other transactions.
      final payjoinInputs = await _payjoin.getInputsFromOngoingPayjoins();

      debugPrint(
        'Wallet id $walletId building psbt. PayjoinInputs: $payjoinInputs',
      );

      final psbt = await _walletManager.buildPsbt(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        feeRateSatPerVb: feeRateSatPerVb,
        drain: drain,
        unspendableInputs:
            ignoreUnspendableInputs == true ? null : payjoinInputs,
      );

      return psbt;
    } on NoSpendableUtxoException {
      rethrow;
    } catch (e) {
      throw FailedToBuildPsbtException(e.toString());
    }
  }
}

class FailedToBuildPsbtException implements Exception {
  final String message;

  FailedToBuildPsbtException(this.message);
}
