import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';

abstract interface class InteracSecurityDetailsRepository {
  @useResult
  Future<Result<void, RecipientsFailure>> update(
    InteracSecurityDetails details,
  );
}
