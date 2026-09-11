import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What a built Bitcoin pay payin is worth knowing about.
typedef PreparedPayBitcoinPayin = ({
  String unsignedPsbt,
  int txSize,
  bool isToSelf,
});

/// Builds the unsigned PSBT for a Bitcoin pay payin.
class PreparePayBitcoinPayinUsecase {
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;

  const PreparePayBitcoinPayinUsecase({
    required this._prepareBitcoinSendUsecase,
  });

  @useResult
  Future<Result<PreparedPayBitcoinPayin, PayFailure>> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    try {
      final prepared = await _prepareBitcoinSendUsecase.execute(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        amountSat: amountSat,
        drain: drain,
        selectedInputs: selectedInputs,
        replaceByFee: replaceByFee,
      );
      return Ok((
        unsignedPsbt: prepared.unsignedPsbt,
        txSize: prepared.txSize,
        isToSelf: prepared.isToSelf,
      ));
    } on InsufficientFundsException catch (e, st) {
      // PrepareBitcoinSendUsecase rethrows this rather than wrapping it,
      // precisely so the caller can name it. The estimate's balance check
      // compares the amount without fees, so "covers the amount but not the
      // fees" — and coin control that selects too little — land here, not
      // there. The Liquid twin has always reported these correctly.
      log.warning('Bitcoin pay payin is short of funds', error: e, trace: st);
      return Err(
        PayInsufficientBalanceFailure(
          requiredAmountSat: amountSat ?? 0,
          logMessage: e.message,
        ),
      );
    } on NoSpendableUtxoException catch (e, st) {
      log.warning('Bitcoin wallet has no spendable utxo', error: e, trace: st);
      return Err(
        PayInsufficientBalanceFailure(
          requiredAmountSat: amountSat ?? 0,
          logMessage: e.message,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to build the Bitcoin pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
