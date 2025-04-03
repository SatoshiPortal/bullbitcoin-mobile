import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/wallet/data/repository/bdk_wallet_repository_impl.dart';
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
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    bool? ignoreUnspendableInputs,
    List<TxInput>? selectableInputs,
    bool replaceByFees = true,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw FailedToBuildTransactionException(
          'Amount cannot be empty if drain is not true',
        );
      }
      final wallet = await _walletManager.getWallet(walletId);
      if (wallet == null) {
        throw FailedToBuildTransactionException('Wallet not found');
      }

      final isLiquid = wallet.network.isLiquid;
      List<TxInput>? unspendableInputs;

      // Only apply Payjoin logic for Bitcoin transactions
      if (!isLiquid && ignoreUnspendableInputs != true) {
        // For Bitcoin, check for ongoing Payjoin inputs
        final payjoinInputs = await _payjoin.getInputsFromOngoingPayjoins();
        unspendableInputs = payjoinInputs;
        debugPrint(
          'Bitcoin wallet id $walletId building psbt. PayjoinInputs: $payjoinInputs',
        );
      } else {
        // For Liquid, ignore Payjoin completely
        debugPrint(
          'Liquid wallet id $walletId building psbt. No Payjoin support.',
        );
      }

      final psbt = await _walletManager.buildUnsigned(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        unspendableInputs: unspendableInputs,
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
