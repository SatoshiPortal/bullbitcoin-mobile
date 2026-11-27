import 'package:primitives/primitives.dart';
import 'package:rust_bindings/boltz.dart';
import 'package:send/send.dart';

import '../domain/lnurl_pay_limits.dart';
import '../domain/lnurl_pay_limits_repository.dart';

final class BoltzLnurlPayLimitsRepository implements LnurlPayLimitsRepository {
  const BoltzLnurlPayLimitsRepository();

  @override
  Future<Result<LnurlPayLimits, SendFailure>> read(String recipient) async {
    try {
      final bounds = await Lnurl(value: recipient).fetchPayLimits();
      final limits = LnurlPayLimits.fromMillisatoshis(
        bounds.minSendableMsat,
        bounds.maxSendableMsat,
        description: bounds.description,
      );
      return limits == null
          ? const Err(SendLnurlNoPayableAmountFailure())
          : Ok(limits);
    } on BoltzError {
      return const Err(SendLnurlLimitsUnavailableFailure());
    }
  }
}
