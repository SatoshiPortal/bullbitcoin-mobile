import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:meta/meta.dart';

abstract interface class RecipientUpdateRepository {
  @useResult
  Future<Result<void, RecipientsFailure>> update(
    String recipientId,
    RecipientDetails recipientDetails, {
    required bool isTestnet,
  });

  @useResult
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails(
    InteracSecurityDetails details, {
    required bool isTestnet,
  });
}
