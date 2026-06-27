import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:flutter/widgets.dart';

extension ImportMnemonicFailureL10n on ImportMnemonicFailure {
  String toTranslated(BuildContext context) => switch (this) {
        ImportMnemonicDuplicateFailure() =>
          context.loc.importMnemonicDuplicateError,
        ImportMnemonicEmptyLabelFailure() =>
          context.loc.importMnemonicEmptyLabelError,
        ImportMnemonicNullMnemonicFailure() => context.loc.oopsSomethingWentWrong,
        ImportMnemonicUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
