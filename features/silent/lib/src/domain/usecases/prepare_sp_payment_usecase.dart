import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:silent/src/domain/ports/sp_payments_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Builds a transaction simulation (coin selection + fee preview) for the
/// confirm screen. Does not sign or broadcast.
class PrepareSpPaymentUsecase {
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final SpPaymentsPort _repository;

  PrepareSpPaymentUsecase({
    required this._getSpFeatureGateUsecase,
    required this._repository,
  });

  @useResult
  Future<Result<SilentTxDraft, SilentFailure>> execute({
    required List<SilentRecipient> recipients,
    required BigInt feerateSatVb,
  }) async {
    if (!await _getSpFeatureGateUsecase.execute()) {
      return const Err(SilentUnsupportedNetwork());
    }
    return _repository.preparePsbt(
      recipients: recipients,
      feerateSatVb: feerateSatVb,
    );
  }
}
