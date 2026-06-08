import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

sealed class FundExchangePresentationError implements Exception {
  const FundExchangePresentationError();

  static FundExchangePresentationError fromApplicationError(
    FundExchangeApplicationError error,
  ) {
    return switch (error) {
      FetchFundingDetailsFailed(:final isOptionUnavailable, :final code) =>
        isOptionUnavailable
            ? FundingOptionUnavailable(code: code)
            : const LoadFundingDetailsFailed(),
      FetchInstitutionsFailed(:final message, :final emptyList) =>
        LoadInstitutionsFailed(message: message, emptyList: emptyList),
      InvalidInstitution() => const LoadInstitutionsFailed(),
      ResponsibilityConsentRegistrationFailed() =>
        const ScamWarningConsentRegistrationFailed(),
      UnsupportedJurisdiction() => const UnexpectedError(),
      FundExchangeUnknownError() => const UnexpectedError(),
    };
  }

  String displayMessage(AppLocalizations loc);
}

class LoadFundingDetailsFailed extends FundExchangePresentationError {
  const LoadFundingDetailsFailed();

  @override
  String displayMessage(AppLocalizations loc) =>
      loc.fundExchangeErrorLoadingDetails;
}

class FundingOptionUnavailable extends FundExchangePresentationError {
  const FundingOptionUnavailable({this.code});

  final String? code;

  @override
  String displayMessage(AppLocalizations loc) => switch (code) {
    'ERR_ORD_PO404' => loc.fundExchangeErrorOrdPo404,
    'ERR_RCP_POSINPE404' => loc.fundExchangeErrorRcpPosinpe404,
    _ => loc.fundExchangeErrorRcpPo404,
  };
}

class LoadInstitutionsFailed extends FundExchangePresentationError {
  const LoadInstitutionsFailed({this.message = '', this.emptyList = false});

  final String message;
  final bool emptyList;

  @override
  String displayMessage(AppLocalizations loc) => emptyList
      ? loc.fundExchangeErrorFetchingBankCodes
      : (message.isNotEmpty ? message : loc.fundExchangeErrorLoadingDetails);
}

class ScamWarningConsentRegistrationFailed
    extends FundExchangePresentationError {
  const ScamWarningConsentRegistrationFailed();

  @override
  String displayMessage(AppLocalizations loc) =>
      loc.fundExchangeErrorLoadingDetails;
}

class UnexpectedError extends FundExchangePresentationError {
  const UnexpectedError();

  @override
  String displayMessage(AppLocalizations loc) =>
      loc.fundExchangeErrorLoadingDetails;
}
