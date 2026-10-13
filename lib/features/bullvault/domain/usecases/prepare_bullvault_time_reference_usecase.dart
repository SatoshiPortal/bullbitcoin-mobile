import 'package:bb_mobile/core/blockchain/domain/usecases/get_bitcoin_chain_tip_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class PrepareBullVaultTimeReferenceUsecase {
  final GetBitcoinChainTipUsecase _getBitcoinChainTipUsecase;
  final DateTime Function() _clock;

  const PrepareBullVaultTimeReferenceUsecase(
    this._getBitcoinChainTipUsecase, {
    this._clock = DateTime.now,
  });

  @useResult
  Future<Result<BullVaultTimeReference, BullVaultFailure>> execute({
    required bool isTestnet,
  }) async {
    try {
      final chainTip = await _getBitcoinChainTipUsecase.execute(
        isTestnet: isTestnet,
      );
      final now = _clock().toUtc();
      final difference =
          ((now.millisecondsSinceEpoch ~/ 1000) - chainTip.medianTimePast)
              .abs();
      if (difference >
          BullVaultTimeReference.maxChainTimeDifference.inSeconds) {
        return const Err(BullVaultClockMismatchFailure());
      }
      return Ok(
        BullVaultTimeReference(
          deviceTime: now,
          chainHeight: chainTip.height,
          medianTimePast: chainTip.medianTimePast,
        ),
      );
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to prepare the BullVault time reference',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultCreationFailure());
    }
  }
}
