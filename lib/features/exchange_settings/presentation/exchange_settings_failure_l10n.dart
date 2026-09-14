import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:flutter/widgets.dart';

extension ExchangeSettingsFailureL10n on ExchangeSettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ExchangeSettingsStatisticsUnavailableFailure() =>
      context.loc.exchangeSettingsErrorLoadingStatistics,
    ExchangeSettingsDefaultWalletsUnavailableFailure() =>
      context.loc.exchangeSettingsErrorLoadingWallets,
    ExchangeSettingsWalletAddressEmptyFailure() =>
      context.loc.exchangeSettingsErrorAddressEmpty,
    ExchangeSettingsWalletSaveFailure() =>
      context.loc.exchangeSettingsErrorSavingWallet,
    ExchangeSettingsWalletDeleteFailure() =>
      context.loc.exchangeSettingsErrorDeletingWallet,
    ExchangeSettingsAccountUnavailableFailure() =>
      context.loc.exchangeSettingsErrorLoadingAccount,
    ExchangeSettingsDocumentAlreadySubmittedFailure() =>
      context.loc.exchangeSettingsErrorDocumentAlreadySubmitted,
    ExchangeSettingsDocumentEmptyFailure() =>
      context.loc.exchangeSettingsErrorDocumentEmpty,
    ExchangeSettingsDocumentTooLargeFailure() =>
      context.loc.exchangeSettingsErrorDocumentTooLarge,
    ExchangeSettingsDocumentTypeNotAllowedFailure() =>
      context.loc.exchangeSettingsErrorDocumentTypeNotAllowed,
    ExchangeSettingsDocumentUnreadableFailure() =>
      context.loc.exchangeSettingsErrorDocumentUnreadable,
    // The exchange's own rejection sentence lives in `logMessage` and stays
    // there; the user gets a message we wrote.
    ExchangeSettingsDocumentUploadFailure() =>
      context.loc.exchangeSettingsErrorUploadingDocument,
    // Never `logMessage`.
    ExchangeSettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
