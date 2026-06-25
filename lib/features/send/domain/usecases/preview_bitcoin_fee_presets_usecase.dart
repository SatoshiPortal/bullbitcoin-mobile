import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/send/domain/usecases/preview_bitcoin_fee_usecase.dart';

/// Builds the fastest/economic/slow PSBTs in parallel and reports a real
/// fee per slot. Same-rate presets share one build — when the mempool is
/// quiet and `economic == slow == 1 sat/vB`, BDK's randomized coin
/// selection would otherwise produce two PSBTs with different vsizes
/// making one tile look more expensive than the other at the same rate.
///
/// Returns one slot per [FeeSelection] (excluding [FeeSelection.custom]).
/// The caller folds the result into [BitcoinFeePreviewCache] via
/// `cache.withSlot(...)` or `copyWith`.
class PreviewBitcoinFeePresetsUsecase {
  final PreviewBitcoinFeeUsecase _previewOne;

  PreviewBitcoinFeePresetsUsecase({
    required PreviewBitcoinFeeUsecase previewBitcoinFeeUsecase,
  }) : _previewOne = previewBitcoinFeeUsecase;

  Future<Map<FeeSelection, BitcoinFeePreviewSlot>> execute({
    required FeeOptions presets,
    required String walletId,
    required String address,
    required int amountSat,
    required bool replaceByFee,
    required List<WalletUtxo> selectedInputs,
    required bool drain,
  }) async {
    String rateKey(NetworkFee fee) => switch (fee) {
      AbsoluteFee(:final sats) => 'abs:$sats',
      RelativeFee(:final satPerKwu) => 'kwu:$satPerKwu',
    };
    final byRate = <String, Future<BitcoinFeePreviewSlot>>{};
    Future<BitcoinFeePreviewSlot> resolve(NetworkFee fee) =>
        byRate.putIfAbsent(
          rateKey(fee),
          () => _previewOne.execute(
            walletId: walletId,
            address: address,
            amountSat: amountSat,
            networkFee: fee,
            replaceByFee: replaceByFee,
            selectedInputs: selectedInputs,
            drain: drain,
          ),
        );
    final results = await Future.wait([
      resolve(presets.fastest),
      resolve(presets.economic),
      resolve(presets.slow),
    ]);
    return {
      FeeSelection.fastest: results[0],
      FeeSelection.economic: results[1],
      FeeSelection.slow: results[2],
    };
  }
}
