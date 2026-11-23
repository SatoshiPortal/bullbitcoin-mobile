import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;

extension ImportMnemonicScanFailureL10n on ImportMnemonicScanFailure {
  String toTranslated(BuildContext context) => switch (this) {
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
