import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';

class UpdateInteracSecurityDetailsUsecase {
  const UpdateInteracSecurityDetailsUsecase(this._repository);

  final InteracSecurityDetailsRepository _repository;

  Future<Result<void, RecipientsFailure>> execute(
    InteracSecurityDetails details,
  ) => _repository.update(details);
}
