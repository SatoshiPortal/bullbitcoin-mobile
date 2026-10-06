import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';

class UpdateInteracSecurityDetailsUsecase {
  final InteracSecurityDetailsRepository _repository;

  const UpdateInteracSecurityDetailsUsecase(this._repository);

  @useResult
  Future<Result<void, RecipientsFailure>> execute(
    InteracSecurityDetails details,
  ) => _repository.update(details);
}
