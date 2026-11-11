import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/validate_bitcoin_selection_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

typedef PreparedBitcoinSend = ({
  String unsignedPsbt,
  int txSize,
  bool isToSelf,
});

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

  @useResult
  Future<Result<PreparedBitcoinSend, WalletFailure>> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    try {
      if (amountSat == null && drain == false) {
        return const Err(WalletTransactionBuildFailure('Amount required'));
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
              filteredSelectedInputs == null ||
              filteredSelectedInputs.length != selectedInputs.length)) {
        return const Err(WalletSelectedInputsUnavailableFailure());
      }

      final built = await _bitcoinWalletRepository.buildPsbt(
        walletId: walletId,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        unspendable: unspendableUtxos,
        selected: filteredSelectedInputs,
        selectedOnly: selectedOnly,
        replaceByFee: replaceByFee,
      );
      final String psbt;
      switch (built) {
        case Ok(:final value):
          psbt = value;
        case Err(:final failure):
          return Err(failure);
      }
      final size = await _bitcoinWalletRepository.getTxSize(psbt: psbt);
      final isToSelf = await _bitcoinWalletRepository.isAddressOfWallet(
        address,
        walletId: walletId,
      );
      return Ok((unsignedPsbt: psbt, txSize: size, isToSelf: isToSelf));
    } on NoSpendableUtxoException {
      return Err(
        selectedOnly || (selectedInputs?.isNotEmpty ?? false)
            ? const WalletSelectedInputsUnavailableFailure()
            : const WalletNoSpendableInputsFailure(),
      );
    } on InsufficientFundsException {
      return const Err(WalletInsufficientFundsFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Bitcoin transaction preparation failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletTransactionBuildFailure());
    }
  }
}
