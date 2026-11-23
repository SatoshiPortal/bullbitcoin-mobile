import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter/widgets.dart';

extension ImportMnemonicFailureL10n on ImportMnemonicFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ImportMnemonicCustodyMetadataFailure() =>
      context.loc.parentCustodyMetadataUnavailable,
    ImportMnemonicDuplicateFailure() =>
      context.loc.importMnemonicDuplicateError,
    ImportMnemonicEmptyLabelFailure() =>
      context.loc.importMnemonicEmptyLabelError,
    ImportMnemonicNullMnemonicFailure() => context.loc.oopsSomethingWentWrong,
    ImportMnemonicUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    ImportMnemonicScanServerUnavailableFailure() =>
      context.loc.importMnemonicScanServerUnavailable,
    ImportMnemonicScanTimeoutFailure() => context.loc.importMnemonicScanTimeout,
    ImportMnemonicScanInvalidMnemonicFailure() =>
      context.loc.importMnemonicScanInvalidMnemonic,
    ImportMnemonicScanUnsupportedFailure() =>
      context.loc.importMnemonicUnsupportedScript,
    ImportMnemonicScanUnexpectedFailure() =>
      context.loc.importMnemonicScanUnavailable,
  };
}
