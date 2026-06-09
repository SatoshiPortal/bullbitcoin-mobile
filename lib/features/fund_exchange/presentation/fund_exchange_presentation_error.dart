import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_api_error_copy.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

sealed class FundExchangePresentationError implements Exception {
  const FundExchangePresentationError();

  static FundExchangePresentationError fromApplicationError(
    FundExchangeApplicationError error,
  ) {
    return switch (error) {
      FetchFundingDetailsFailed(
        :final code,
        :final message,
        :final messageData,
      ) =>
        FundExchangeApiError(
          code: code,
          message: message,
          messageData: messageData,
        ),
      FetchInstitutionsFailed(
        :final message,
        :final code,
        :final messageData,
        :final emptyList,
      ) =>
        FundExchangeApiError(
          code: code,
          message: message,
          messageData: messageData,
          emptyInstitutionList: emptyList,
        ),
      InvalidInstitution() => const LoadInstitutionsFailed(),
      ResponsibilityConsentRegistrationFailed() =>
        const ScamWarningConsentRegistrationFailed(),
      UnsupportedJurisdiction() => const UnexpectedError(),
      FundExchangeUnknownError() => const UnexpectedError(),
    };
  }

  String? displayTitle(AppLocalizations loc);

  String displayMessage(AppLocalizations loc);
}

class FundExchangeApiError extends FundExchangePresentationError {
  const FundExchangeApiError({
    this.code,
    required this.message,
    this.messageData,
    this.emptyInstitutionList = false,
  });

  final String? code;
  final String message;
  final Map<String, String>? messageData;
  final bool emptyInstitutionList;

  @override
  String? displayTitle(AppLocalizations loc) {
    if (emptyInstitutionList) return null;
    return FundExchangeApiErrorCopy.title(code, loc);
  }

  @override
  String displayMessage(AppLocalizations loc) {
    if (emptyInstitutionList) {
      return loc.fundExchangeErrorFetchingBankCodes;
    }
    return FundExchangeApiErrorCopy.message(
      code: code,
      backendMessage: message,
      messageData: messageData,
      loc: loc,
    );
  }
}

class LoadFundingDetailsFailed extends FundExchangePresentationError {
  const LoadFundingDetailsFailed();

  @override
  String? displayTitle(AppLocalizations loc) => null;

  @override
  String displayMessage(AppLocalizations loc) =>
      loc.fundExchangeErrorLoadingDetails;
}

class LoadInstitutionsFailed extends FundExchangePresentationError {
  const LoadInstitutionsFailed({this.message = ''});

  final String message;

  @override
  String? displayTitle(AppLocalizations loc) => null;

  @override
  String displayMessage(AppLocalizations loc) => message.isNotEmpty
      ? message
      : loc.fundExchangeErrorLoadingDetails;
}

class ScamWarningConsentRegistrationFailed
    extends FundExchangePresentationError {
  const ScamWarningConsentRegistrationFailed();

  @override
  String? displayTitle(AppLocalizations loc) => null;

  @override
  String displayMessage(AppLocalizations loc) =>
      loc.fundExchangeErrorLoadingDetails;
}

class UnexpectedError extends FundExchangePresentationError {
  const UnexpectedError();

  @override
  String? displayTitle(AppLocalizations loc) => null;

  @override
  String displayMessage(AppLocalizations loc) =>
      loc.fundExchangeErrorLoadingDetails;
}
