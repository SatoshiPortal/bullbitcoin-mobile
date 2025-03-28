
import 'package:bb_mobile/core/bitcoin/data/repository/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/tx_input.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:flutter/foundation.dart';

class BuildTransactionUsecase {
  final PayjoinRepository _payjoin;
  final WalletManagerService _walletManager;

  BuildTransactionUsecase({
    required PayjoinRepository payjoinRepository,
    required WalletManagerService walletManagerService,
  })  : _payjoin = payjoinRepository,
        _walletManager = walletManagerService;

  Future<Transaction> execute({
    required String walletId,
    required String address,
    BigInt? amountSat,
    double? feeRateSatPerVb,
    bool? drain,
    bool? ignoreUnspendableInputs,
    List<TxInput>? selectableInputs,
    bool replaceByFees = true,
  }) async {
    try {
      // Inputs that are already used in ongoing payjoin sessions should not be
      //  used in other transactions.
      final payjoinInputs = await _payjoin.getInputsFromOngoingPayjoins();

      debugPrint(
        'Wallet id $walletId building psbt. PayjoinInputs: $payjoinInputs',
      );

      final psbt = await _walletManager.buildUnsigned(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        feeRateSatPerVb: feeRateSatPerVb,
        drain: drain,
        unspendableInputs:
            ignoreUnspendableInputs == true ? null : payjoinInputs,
        selectableInputs: selectableInputs,
        replaceByFees: replaceByFees,
      );

      return psbt;
    } on NoSpendableUtxoException {
      rethrow;
    } catch (e) {
      throw FailedToBuildTransactionException(e.toString());
    }
  }
}

class FailedToBuildTransactionException implements Exception {
  final String message;

  FailedToBuildTransactionException(this.message);
}
