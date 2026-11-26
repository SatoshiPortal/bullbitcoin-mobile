import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:send/send.dart';

import '../lnurl_pay_limits.dart';
import '../lnurl_pay_limits_repository.dart';

final class LoadLnurlPayLimitsUsecase {
  final LnurlPayLimitsRepository _repository;

  const LoadLnurlPayLimitsUsecase(this._repository);

  @useResult
  Future<Result<LnurlPayLimits, SendFailure>> execute(String recipient) =>
      _repository.read(recipient);
}
