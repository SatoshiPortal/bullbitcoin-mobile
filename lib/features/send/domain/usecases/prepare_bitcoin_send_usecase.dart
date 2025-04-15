import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:flutter/foundation.dart';

class PrepareBitcoinSendUsecase {
  final PayjoinRepository _payjoin;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  PrepareBitcoinSendUsecase({
    required PayjoinRepository payjoinRepository,
    required BitcoinWalletRepository bitcoinWalletRepository,
  })  : _payjoin = payjoinRepository,
        _bitcoinWalletRepository = bitcoinWalletRepository;

  Future<String> execute({
    required String origin,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    bool? ignoreUnspendableInputs,
    List<Utxo>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw Exception('Amount cannot be empty if drain is not true');
      }

      List<Utxo>? unspendableInputs;
      if (ignoreUnspendableInputs != null && !ignoreUnspendableInputs) {
        // For Bitcoin, check for ongoing Payjoin inputs
        final payjoinInputs = await _payjoin.getInputsFromOngoingPayjoins();
        unspendableInputs = payjoinInputs;
        debugPrint(
          'Bitcoin wallet id $origin building psbt. PayjoinInputs: $payjoinInputs',
        );
      }
      final psbt = await _bitcoinWalletRepository.buildPsbt(
        origin: origin,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        unspendable: unspendableInputs,
        selected: selectedInputs,
        replaceByFee: replaceByFee,
      );

      return psbt;
    } on NoSpendableUtxoException {
      rethrow;
    } catch (e) {
      throw PrepareBitcoinSendException(e.toString());
    }
  }
}

class PrepareBitcoinSendException implements Exception {
  final String message;

  PrepareBitcoinSendException(this.message);
}
