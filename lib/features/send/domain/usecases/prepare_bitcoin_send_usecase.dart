import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_utxo.dart';

class PrepareBitcoinSendUsecase {
  final PayjoinRepository _payjoin;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  PrepareBitcoinSendUsecase({
    required PayjoinRepository payjoinRepository,
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _payjoin = payjoinRepository,
       _bitcoinWalletRepository = bitcoinWalletRepository;

  Future<({String unsignedPsbt, int txSize})> execute({
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

        log.info(
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
      final size = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      return (unsignedPsbt: psbt, txSize: size);
    } on NoSpendableUtxoException {
      rethrow;
    } catch (e) {
      throw PrepareBitcoinSendException(e.toString());
    }
  }
}

class PrepareBitcoinSendException extends BullException {
  PrepareBitcoinSendException(super.message);
}
