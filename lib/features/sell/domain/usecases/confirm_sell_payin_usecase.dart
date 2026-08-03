import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/liquid_tx.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:meta/meta.dart';

/// Derives a bitcoin txid from an (unsigned) PSBT. Injectable so the money path
/// can be unit-tested without a real BDK transaction.
typedef BitcoinTxidFromPsbt = Future<String> Function(String psbt);

/// Derives a liquid txid from a signed PSET. Injectable for the same reason.
typedef LiquidTxidFromPset = Future<String> Function(String pset);

Future<String> _defaultBitcoinTxidFromPsbt(String psbt) async =>
    (await BitcoinTx.fromPsbt(psbt)).txid;

Future<String> _defaultLiquidTxidFromPset(String pset) async =>
    (await LiquidTx.fromPset(pset)).txid;

/// Builds, signs and broadcasts the payin transaction for a sell order.
///
/// The broadcast is the point of no return: once it succeeds the user's money
/// has moved, so the payin is reported as a success even if the after-the-fact
/// bookkeeping (transaction labelling) fails — that is logged but never turned
/// into a [SellSendPaymentFailure], which would otherwise invite a double-spend
/// retry. Every failure before or during broadcast is mapped to a sealed
/// [SellFailure], and the raw exception never leaves the boundary.
class ConfirmSellPayinUsecase {
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final SignBitcoinTxUsecase _signBitcoinTxUsecase;
  final SignLiquidTxUsecase _signLiquidTxUsecase;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final BroadcastLiquidTransactionUsecase _broadcastLiquidTransactionUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final LabelsFacade _labelsFacade;
  final BitcoinTxidFromPsbt _bitcoinTxidFromPsbt;
  final LiquidTxidFromPset _liquidTxidFromPset;

  ConfirmSellPayinUsecase({
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._signBitcoinTxUsecase,
    required this._signLiquidTxUsecase,
    required this._broadcastBitcoinTransactionUsecase,
    required this._broadcastLiquidTransactionUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._labelsFacade,
    this._bitcoinTxidFromPsbt = _defaultBitcoinTxidFromPsbt,
    this._liquidTxidFromPset = _defaultLiquidTxidFromPset,
  });

  @useResult
  Future<Result<({String txid, int? updatedAbsoluteFees}), SellFailure>>
  execute({
    required Wallet wallet,
    required SellOrder sellOrder,
    required int? absoluteFees,
    List<WalletUtxo> selectedInputs = const [],
    bool replaceByFee = false,
  }) async {
    final payinAmountSat = ConvertAmount.btcToSats(sellOrder.payinAmount);

    final String txid;
    final int? updatedAbsoluteFees;
    try {
      if (wallet.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: sellOrder.liquidAddress!,
          amountSat: payinAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        final signedPset = await _signLiquidTxUsecase.execute(
          pset: pset,
          walletId: wallet.id,
        );
        // Derive the txid before broadcasting so nothing fallible runs after
        // the money has moved.
        txid = await _liquidTxidFromPset(signedPset);
        updatedAbsoluteFees = null;
        await _broadcastLiquidTransactionUsecase.execute(signedPset);
      } else {
        if (absoluteFees == null) {
          return const Err(SellPrepareTransactionFailure());
        }
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: sellOrder.bitcoinAddress!,
          amountSat: payinAmountSat,
          networkFee: NetworkFee.absolute(absoluteFees),
          selectedInputs: selectedInputs.isNotEmpty ? selectedInputs : null,
          replaceByFee: replaceByFee,
        );
        updatedAbsoluteFees = await _calculateBitcoinAbsoluteFeesUsecase
            .execute(psbt: preparedSend.unsignedPsbt);
        final signedTx = await _signBitcoinTxUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
          walletId: wallet.id,
        );
        txid = await _bitcoinTxidFromPsbt(preparedSend.unsignedPsbt);
        await _broadcastBitcoinTransactionUsecase.execute(
          signedTx.signedPsbt,
          isPsbt: true,
        );
      }
    } catch (e, st) {
      log.severe(
        message: 'sell confirm payin failed',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SellSendPaymentFailure(e.runtimeType.toString()));
    }

    // Broadcast succeeded: the payin is done. Labelling is best-effort and must
    // never demote a completed payin to a failure.
    await _storeSellLabel(walletId: wallet.id, txid: txid);

    return Ok((txid: txid, updatedAbsoluteFees: updatedAbsoluteFees));
  }

  Future<void> _storeSellLabel({
    required String walletId,
    required String txid,
  }) async {
    try {
      await _labelsFacade.store(
        NewLabel.tx(
          transactionId: txid,
          label: LabelSystem.exchangeSell.label,
          origin: walletId,
        ),
      );
    } catch (e, st) {
      log.warning(
        'sell payin label store failed (payin already broadcast)',
        error: e.runtimeType,
        trace: st,
      );
    }
  }
}
