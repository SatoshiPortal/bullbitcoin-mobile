import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Sats;

class PrepareBitcoinSendUsecase {
  final PayjoinSessions _payjoin;
  final BitcoinSendPort _bitcoinWalletRepository;
  final WalletUtxoRepository _walletUtxoRepository;
  late final ValidateBitcoinSelectionUsecase _validateBitcoinSelectionUsecase;

  PrepareBitcoinSendUsecase({
    required PayjoinSessions payjoinSessions,
    required this._walletUtxoRepository,
    required this._bitcoinWalletRepository,
  }) : _payjoin = payjoinSessions {
    _validateBitcoinSelectionUsecase = ValidateBitcoinSelectionUsecase(
      payjoinSessions: _payjoin,
      walletUtxoRepository: _walletUtxoRepository,
    );
  }

  Future<
    ({
      String unsignedPsbt,
      int txSize,
      bool isToSelf,
      List<Sats> recipientAmountsSat,
    })
  >
  execute({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<WalletUtxo>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    validateBitcoinTransactionRecipients(recipients);
    try {
      final remainderRecipients = recipients
          .where((recipient) => recipient.receivesRemainder)
          .toList();

      // D7: a frozen coin must never be spendable in any transaction. Always
      // compute the unspendable set (user-frozen ∪ payjoin-derived) and feed it
      // to every PSBT build (normal send + drain). The two sources are kept
      // explicit on purpose; the future payjoin-unification collapses
      // `_unspendableFor` to a single read.
      final unspendableUtxos = await _validateBitcoinSelectionUsecase.execute(
        walletId: walletId,
        selectedInputs: selectedInputs,
      );

      log.info(
        'Bitcoin wallet id $walletId building psbt. Unspendable utxos: $unspendableUtxos',
      );

      // Belt-and-suspenders: defensively strip any selected input that falls in
      // the unspendable set before building (guards a future send-from-selected
      // path from ever pinning a frozen coin).
      final filteredSelectedInputs = selectedInputs
          ?.where(
            (utxo) =>
                !unspendableUtxos.contains((txId: utxo.txId, vout: utxo.vout)),
          )
          .toList();
      if (selectedOnly &&
          (selectedInputs == null ||
              selectedInputs.isEmpty ||
              filteredSelectedInputs!.length != selectedInputs.length)) {
        throw SelectedInputsUnavailableException(
          'One or more selected inputs are unavailable',
        );
      }

      final psbt = await _bitcoinWalletRepository.buildPsbt(
        walletId: walletId,
        recipients: recipients,
        networkFee: networkFee,
        unspendable: unspendableUtxos,
        selected: filteredSelectedInputs,
        selectedOnly: selectedOnly,
        replaceByFee: replaceByFee,
      );
      final size = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      final isToSelf = await _bitcoinWalletRepository.areAddressesOfWallet([
        for (final recipient in recipients) recipient.address,
      ], walletId: walletId);
      final recipientAmountsSat = remainderRecipients.isEmpty
          ? [for (final recipient in recipients) recipient.amountSat!]
          : await _bitcoinWalletRepository.getRecipientAmounts(
              psbt: psbt,
              recipients: recipients,
              walletId: walletId,
            );
      return (
        unsignedPsbt: psbt,
        txSize: size,
        isToSelf: isToSelf,
        recipientAmountsSat: recipientAmountsSat,
      );
    } on NoSpendableUtxoException catch (error) {
      if (selectedOnly) {
        throw SelectedInputsUnavailableException(error.message);
      }
      rethrow;
    } on InsufficientFundsException {
      rethrow;
    } on SelectedInputsUnavailableException {
      rethrow;
    } catch (e) {
      throw PrepareBitcoinSendException(e.toString());
    }
  }
}

class PrepareBitcoinSendException extends BullException {
  PrepareBitcoinSendException(super.message);
}
