import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_account.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/core/utils/result.dart' show Err, Ok, Result;
export '../domain/exchange_failure.dart';
export '../exchange_locator.dart' show ExchangeLocator;
export '../presentation/exchange_failure_l10n.dart' show ExchangeFailureL10n;
export '../ui/exchange_router.dart'
    show ExchangeRoute, ExchangeRouter, ExchangeRouterConfig;
export '../ui/exchange_scope.dart'
    show ExchangeScope, ExchangeSessionBuilder, ExchangeSessionListener;
export '../ui/widgets/exchange_account_actions.dart'
    show ExchangeAccountActions;
export '../ui/widgets/exchange_amount_currency_dropdown.dart'
    show ExchangeAmountCurrencyDropdown;
export '../ui/widgets/exchange_amount_input_field.dart'
    show ExchangeAmountInputField;
export 'exchange_account.dart' show ExchangeAccount;

class ExchangeFacade {
  final GetExchangeAccountUsecase _getExchangeAccountUsecase;

  const ExchangeFacade({required this._getExchangeAccountUsecase});

  @useResult
  Future<Result<ExchangeAccount, ExchangeFailure>> getAccount() async {
    final result = await _getExchangeAccountUsecase.execute();
    return result.map(
      (account) => ExchangeAccount(
        userNumber: account.userNumber,
        firstName: account.profile.firstName,
        lastName: account.profile.lastName,
        email: account.email,
        language: account.language,
        currency: account.currency,
        emailNotificationsEnabled: account.emailNotificationsEnabled,
        isFullyVerifiedKycLevel: account.isFullyVerifiedKycLevel,
        isLightKycLevel: account.isLightKycLevel,
        isLimitedKycLevel: account.isLimitedKycLevel,
        isFundingRestricted: account.isFundingRestricted,
        hasConsentedScamWarning: account.hasConsentedScamWarning,
        payjoinReceiveEnabled: account.payjoinReceiveEnabled,
      ),
    );
  }
}
