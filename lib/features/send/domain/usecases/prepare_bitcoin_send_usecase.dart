import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/impl/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:flutter/foundation.dart';

class PrepareBitcoinSendUsecase {
  final PayjoinRepository _payjoin;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  PrepareBitcoinSendUsecase({
    required PayjoinRepository payjoinRepository,
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _payjoin = payjoinRepository,
       _bitcoinWalletRepository = bitcoinWalletRepository;

  Future<String> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    bool? ignoreUnspendableInputs,
    List<WalletUtxo>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw Exception('Amount cannot be empty if drain is not true');
      }

      List<({String txId, int vout})>? unspendableUtxos;
      if (ignoreUnspendableInputs != null && !ignoreUnspendableInputs) {
        // For Bitcoin, check for ongoing Payjoin inputs
        unspendableUtxos = await _payjoin.getUtxosFrozenByOngoingPayjoins();

        debugPrint(
          'Bitcoin wallet id $walletId building psbt. Unspendable utxos: $unspendableUtxos',
        );
      }
      final psbt = await _bitcoinWalletRepository.buildPsbt(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        unspendable: unspendableUtxos,
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
