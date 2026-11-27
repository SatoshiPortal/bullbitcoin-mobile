import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../account_details_failure.dart';
import '../entities/account_info.dart';

class GetAccountInfoUsecase {
  final Exchange _exchange;

  const GetAccountInfoUsecase({required this._exchange});

  @useResult
  Future<Result<AccountInfo, ExchangeFailure>> execute() async =>
      (await _exchange.getUserSummary())
          .map(
            (summary) => AccountInfo(
              userNumber: summary.userNumber,
              email: summary.email,
              firstName: summary.profile.firstName,
              lastName: summary.profile.lastName,
              verificationLevel: _verificationLevel(summary),
            ),
          )
          .mapErr(accountDetailsFailure);

  VerificationLevel _verificationLevel(UserSummary summary) {
    if (summary.isFullyVerifiedKycLevel) {
      return VerificationLevel.identityVerified;
    } else if (summary.isLightKycLevel) {
      return VerificationLevel.light;
    } else if (summary.isLimitedKycLevel) {
      return VerificationLevel.limited;
    } else {
      return VerificationLevel.notVerified;
    }
  }
}
