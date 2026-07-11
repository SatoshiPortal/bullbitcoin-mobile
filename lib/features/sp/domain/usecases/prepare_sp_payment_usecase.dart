import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Builds a transaction simulation (coin selection + fee preview) for the
/// confirm screen. Does not sign or broadcast.
class PrepareSpPaymentUsecase {
  final SpAccountRepository _repository;

  PrepareSpPaymentUsecase({required this._repository});

  @useResult
  Future<Result<SpTxDraft, SpFailure>> execute({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  }) => _repository.preparePsbt(
    recipients: recipients,
    feerateSatVb: feerateSatVb,
  );
}
