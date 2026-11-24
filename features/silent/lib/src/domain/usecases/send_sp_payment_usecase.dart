import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:silent/src/domain/ports/sp_payments_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Finalizes, signs and broadcasts the confirmed simulation as one
/// irreversible, simulation-pinned step. Returns the broadcast txid.
///
/// The pin (the Rust side rejects a tx whose inputs drifted from the
/// confirmed simulation) lives in the adapter/FFI; this use case just routes
/// the confirmed [SilentTxDraft] through unchanged.
class SendSpPaymentUsecase {
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final SpPaymentsPort _repository;

  SendSpPaymentUsecase({
    required this._getSpFeatureGateUsecase,
    required this._repository,
  });

  @useResult
  Future<Result<String, SilentFailure>> execute({
    required SilentTxDraft draft,
  }) async {
    if (!await _getSpFeatureGateUsecase.execute()) {
      return const Err(SilentUnsupportedNetwork());
    }
    return _repository.finalizeSignBroadcast(draft: draft);
  }
}
