import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
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
import 'package:bb_mobile/core/wallet/domain/unsupported_bitcoin_policy_path_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

typedef PreparedBitcoinSend = ({
  String unsignedPsbt,
  int txSize,
  bool isToSelf,
  List<Sats> recipientAmountsSat,
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
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<WalletUtxo>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
    BitcoinPolicyPath? policyPath,
  }) async {
    validateBitcoinTransactionRecipients(recipients);
    try {
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
        recipients: recipients,
        networkFee: networkFee,
        unspendable: unspendableUtxos,
        selected: filteredSelectedInputs,
        selectedOnly: selectedOnly,
        replaceByFee: replaceByFee,
        policyPath: policyPath,
      );
      final String psbt;
      switch (built) {
        case Ok(:final value):
          psbt = value;
        case Err(:final failure):
          return Err(failure);
      }
      final size = await _bitcoinWalletRepository.getTxSize(
        psbt: psbt,
        walletId: walletId,
      );
      final isToSelf = await _bitcoinWalletRepository.areAddressesOfWallet([
        for (final recipient in recipients) recipient.address,
      ], walletId: walletId);
      final recipientAmountsSat =
          recipients.any((recipient) => recipient.receivesRemainder)
          ? await _bitcoinWalletRepository.getRecipientAmounts(
              psbt: psbt,
              recipients: recipients,
              walletId: walletId,
            )
          : [for (final recipient in recipients) ?recipient.amountSat];
      return Ok((
        unsignedPsbt: psbt,
        txSize: size,
        isToSelf: isToSelf,
        recipientAmountsSat: recipientAmountsSat,
      ));
    } on SelectedBitcoinCoinsUnavailableException {
      return const Err(WalletSelectedInputsUnavailableFailure());
    } on SelectedBitcoinCoinsInsufficientException {
      return const Err(WalletInsufficientFundsFailure());
    } on NoSpendableUtxoException {
      return Err(
        selectedOnly || (selectedInputs?.isNotEmpty ?? false)
            ? const WalletSelectedInputsUnavailableFailure()
            : const WalletNoSpendableInputsFailure(),
      );
    } on InsufficientFundsException {
      return const Err(WalletInsufficientFundsFailure());
    } on UnsupportedBitcoinPolicyPathException {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unsupportedPolicyPath),
      );
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
