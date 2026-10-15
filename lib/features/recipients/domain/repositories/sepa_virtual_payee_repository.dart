import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:meta/meta.dart';

/// The virtual payee lets a SEPA recipient receive Confidential SEPA payouts.
abstract interface class SepaVirtualPayeeRepository {
  @useResult
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  });

  /// Returns `null` when the user has no SEPA recipient with [recipientId].
  @useResult
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  });
}
