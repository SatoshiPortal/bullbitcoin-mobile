import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:send/send.dart';

import 'lnurl_pay_limits.dart';

abstract interface class LnurlPayLimitsRepository {
  @useResult
  Future<Result<LnurlPayLimits, SendFailure>> read(String recipient);
}
