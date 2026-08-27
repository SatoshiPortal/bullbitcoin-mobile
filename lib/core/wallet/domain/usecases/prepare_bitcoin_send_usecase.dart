import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_coin_selection_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

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

  Future<({String unsignedPsbt, int txSize, bool isToSelf})> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
    bool replaceByFee = true,
    BitcoinPolicyPath? policyPath,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        throw Exception('Amount cannot be empty if drain is not true');
      }

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

      final psbt = await _bitcoinWalletRepository.buildPsbt(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        unspendable: unspendableUtxos,
        selected: selectedInputs,
        replaceByFee: replaceByFee,
        policyPath: policyPath,
      );
      final size = await _bitcoinWalletRepository.getTxSize(
        psbt: psbt,
        walletId: walletId,
      );
      final isToSelf = await _bitcoinWalletRepository.isAddressOfWallet(
        address,
        walletId: walletId,
      );
      return (unsignedPsbt: psbt, txSize: size, isToSelf: isToSelf);
    } on NoSpendableUtxoException {
      rethrow;
    } on InsufficientFundsException {
      rethrow;
    } on BitcoinCoinSelectionException {
      rethrow;
    } catch (e) {
      throw PrepareBitcoinSendException(e.toString());
    }
  }
}

class PrepareBitcoinSendException extends BullException {
  PrepareBitcoinSendException(super.message);
}
