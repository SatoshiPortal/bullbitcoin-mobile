import 'package:send/src/consolidation/domain/consolidation_config.dart';
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

final class ConsolidationPreview {
  final PreparedLiquidConsolidation _prepared;

  const ConsolidationPreview(this._prepared);

  int get totalFeeSat => _prepared.totalFee.value.toInt();
  int get transactionCount => _prepared.transactionCount;
}

sealed class ConsolidationFailure extends Failure {
  const ConsolidationFailure();
}

final class ConsolidationPreparationFailure extends ConsolidationFailure {
  const ConsolidationPreparationFailure();
}

final class ConsolidationSubmissionFailure extends ConsolidationFailure {
  final List<String> acceptedTxids;
  final bool outcomeUnknown;

  ConsolidationSubmissionFailure({
    required Iterable<String> acceptedTxids,
    required this.outcomeUnknown,
  }) : acceptedTxids = List.unmodifiable(acceptedTxids);
}

class ConsolidateLiquidWalletUsecase {
  final Spend _spend;

  const ConsolidateLiquidWalletUsecase(this._spend);

  @useResult
  Future<Result<ConsolidationPreview, ConsolidationFailure>> prepare({
    required String walletId,
  }) async =>
      (await _spend.prepareLiquidConsolidation(
            walletId,
            feeRate: NetworkFeeRelayPolicy.minRelay,
            highUtxoThreshold: ConsolidationConfig.highUtxoThreshold,
            maximumInputs: ConsolidationConfig.maximumInputs,
          ))
          .map(ConsolidationPreview.new)
          .mapErr((_) => const ConsolidationPreparationFailure());

  @useResult
  Future<Result<List<String>, ConsolidationFailure>> broadcast(
    ConsolidationPreview preview,
  ) async => (await _spend.submitLiquidConsolidation(preview._prepared)).mapErr(
    (failure) => switch (failure) {
      SpendConsolidationInterruptedFailure(
        :final acceptedTxids,
        :final cause,
      ) =>
        ConsolidationSubmissionFailure(
          acceptedTxids: acceptedTxids,
          outcomeUnknown: cause is SpendBroadcastOutcomeUnknownFailure,
        ),
      _ => ConsolidationSubmissionFailure(
        acceptedTxids: const [],
        outcomeUnknown: failure is SpendBroadcastOutcomeUnknownFailure,
      ),
    },
  );
}
