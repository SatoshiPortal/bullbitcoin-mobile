import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';

/// Builds one unsigned Bitcoin PSBT and reports the real `psbt.fee()` +
/// vsize. No signing, no state mutation — pure compute. The PSBT and
/// txSize are returned so the caller can cache them and reuse the exact
/// bytes at commit time, defeating BDK's randomized coin selection
/// between preview and broadcast.
///
/// On failure (e.g. insufficient funds at the typed rate), returns an
/// empty [BitcoinFeePreviewSlot]. The caller decides whether to surface
/// an error or simply hide the preview.
class PreviewBitcoinFeeUsecase {
  final PrepareBitcoinSendUsecase _prepare;
  final CalculateBitcoinAbsoluteFeesUsecase _calculateFees;

  PreviewBitcoinFeeUsecase({
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    required CalculateBitcoinAbsoluteFeesUsecase
    calculateBitcoinAbsoluteFeesUsecase,
  }) : _prepare = prepareBitcoinSendUsecase,
       _calculateFees = calculateBitcoinAbsoluteFeesUsecase;

  Future<BitcoinFeePreviewSlot> execute({
    required String walletId,
    required String address,
    required int amountSat,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required List<WalletUtxo> selectedInputs,
    required bool drain,
  }) async {
    try {
      final tx = await _prepare.execute(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        amountSat: amountSat,
        replaceByFee: replaceByFee,
        selectedInputs: selectedInputs,
        drain: drain,
      );
      final fee = await _calculateFees.execute(psbt: tx.unsignedPsbt);
      return BitcoinFeePreviewSlot(
        feeSat: fee,
        unsignedPsbt: tx.unsignedPsbt,
        txSize: tx.txSize,
      );
    } catch (e) {
      // Insufficient funds / build error at the typed rate. Log so the
      // failure shows up in the same `[fee-preview]` channel that the
      // caller emits its start/done lines on; the caller treats an
      // empty slot as "hide the preview" rather than a hard error.
      log.info(
        '[fee-preview] build failed at rate '
        '${networkFee is RelativeFee ? networkFee.satPerVbyte : networkFee.value} '
        'amount=$amountSat drain=$drain '
        'selectedInputs=${selectedInputs.length} rbf=$replaceByFee err=$e',
      );
      return const BitcoinFeePreviewSlot();
    }
  }
}
