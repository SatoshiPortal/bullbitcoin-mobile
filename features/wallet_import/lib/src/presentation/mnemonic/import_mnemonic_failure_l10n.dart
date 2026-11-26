import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:flutter/widgets.dart';

extension ImportMnemonicFailureL10n on ImportMnemonicFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ImportMnemonicCustodyMetadataFailure() =>
      context.loc.parentCustodyMetadataUnavailable,
    ImportMnemonicBackupRequiredFailure() =>
      context.loc.importMnemonicBackupRequiredError,
    ImportMnemonicDuplicateFailure() =>
      context.loc.importMnemonicDuplicateError,
    ImportMnemonicEmptyLabelFailure() =>
      context.loc.importMnemonicEmptyLabelError,
    ImportMnemonicNullMnemonicFailure() => context.loc.oopsSomethingWentWrong,
    ImportMnemonicUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
