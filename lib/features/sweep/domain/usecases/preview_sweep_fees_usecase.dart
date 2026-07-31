import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/build_sweep_psbt_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Prices a sweep at one or several fee rates by actually building it.
///
/// Mirrors `send`'s `PreviewBitcoinFeePresetsUsecase` so the shared fee modal
/// shows the same kind of number on every surface: the real `psbt.fee()`, not a
/// rate multiplied by a guessed size. The built PSBT is carried in the slot so
/// the confirm path can broadcast the exact bytes the user priced — BDK's
/// coin selection is randomised, and a rebuild could differ.
///
/// Presets that share a rate share one build: when the mempool is quiet and
/// economic == slow, two independent builds could report different sizes and
/// make one tile look dearer than the other at an identical rate.
class PreviewSweepFeesUsecase {
  final BuildSweepPsbtUsecase _buildSweepPsbt;

  PreviewSweepFeesUsecase({
    required BuildSweepPsbtUsecase buildSweepPsbtUsecase,
  }) : _buildSweepPsbt = buildSweepPsbtUsecase;

  /// One slot per preset (custom excluded). A preset that cannot be built at
  /// its rate — insufficient funds once the fee is covered — comes back empty,
  /// which the modal renders as "no price" rather than an error.
  Future<Map<FeeSelection, BitcoinFeePreviewSlot>> presets({
    required String walletId,
    required SweepPlan plan,
    required FeeOptions presets,
  }) async {
    String rateKey(NetworkFee fee) => switch (fee) {
      AbsoluteFee(:final sats) => 'abs:$sats',
      RelativeFee(:final satPerKwu) => 'kwu:$satPerKwu',
    };

    final byRate = <String, Future<BitcoinFeePreviewSlot>>{};
    Future<BitcoinFeePreviewSlot> resolve(NetworkFee fee) => byRate.putIfAbsent(
      rateKey(fee),
      () => one(walletId: walletId, plan: plan, networkFee: fee),
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

  /// Prices a single rate. Empty slot on failure — the caller decides whether
  /// that is worth surfacing.
  Future<BitcoinFeePreviewSlot> one({
    required String walletId,
    required SweepPlan plan,
    required NetworkFee networkFee,
  }) async {
    final result = await _buildSweepPsbt.execute(
      walletId: walletId,
      plan: plan,
      networkFee: networkFee,
    );

    return switch (result) {
      Ok(:final value) => BitcoinFeePreviewSlot(
        feeSat: value.feeSat.toInt(),
        unsignedPsbt: value.unsignedPsbt,
        txSize: value.txSize,
      ),
      Err(:final failure) => () {
        log.info(
          '[sweep-fee-preview] build failed at '
          '${networkFee is RelativeFee ? networkFee.satPerVbyte : networkFee.value} '
          '→ ${failure.runtimeType}',
        );
        return const BitcoinFeePreviewSlot();
      }(),
    };
  }
}
