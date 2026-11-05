import 'package:primitives/primitives.dart' show BullException;
import 'package:primitives/primitives.dart' show NetworkFee;
import 'package:bull_logger/bull_logger.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/coins/public/coins_facade.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class PrepareBitcoinSendUsecase {
  final PayjoinSessions _payjoin;
  final BitcoinSendPort _bitcoinWalletRepository;
  final LabeledWalletUtxoRepository _walletUtxoRepository;
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
        'Bitcoin PSBT preparation: '
        '${unspendableUtxos.length} unspendable inputs',
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
      );
      final size = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      final isToSelf = await _bitcoinWalletRepository.isAddressOfWallet(
        address,
        walletId: walletId,
      );
      return (unsignedPsbt: psbt, txSize: size, isToSelf: isToSelf);
    } on NoSpendableUtxoException {
      rethrow;
    } on InsufficientFundsException {
      rethrow;
    } catch (e) {
      throw PrepareBitcoinSendException(e.toString());
    }
  }
}

class PrepareBitcoinSendException extends BullException {
  PrepareBitcoinSendException(super.message);
}
