import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';

class CheckConfidentialSepaEligibilityUsecase {
  bool execute(UserSummary userSummary) =>
      userSummary.isFullyVerifiedKycLevel && !userSummary.isCorporate;
}
