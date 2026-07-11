import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Finalizes, signs and broadcasts the confirmed simulation as one
/// irreversible, simulation-pinned step. Returns the broadcast txid.
///
/// The pin (the Rust side rejects a tx whose inputs drifted from the
/// confirmed simulation) lives in the adapter/FFI; this use case just routes
/// the confirmed [SpTxDraft] through unchanged.
class SendSpPaymentUsecase {
  final SpAccountRepository _repository;

  SendSpPaymentUsecase({required this._repository});

  @useResult
  Future<Result<String, SpFailure>> execute({required SpTxDraft draft}) =>
      _repository.finalizeSignBroadcast(draft: draft);
}
