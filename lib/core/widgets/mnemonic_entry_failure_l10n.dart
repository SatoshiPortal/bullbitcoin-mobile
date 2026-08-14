import 'package:bb_mobile/core/failures/mnemonic_entry_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// The only place a [MnemonicEntryFailure] becomes a user-facing string, so the
/// failure family itself stays Flutter-free. The `sealed` switch makes a missing
/// message a compile error.
extension MnemonicEntryFailureL10n on MnemonicEntryFailure {
  String toTranslated(BuildContext context) => switch (this) {
    MnemonicEntryIncompleteFailure() => context.loc.emptyMnemonicWordsError,
    MnemonicEntryInvalidChecksumFailure() =>
      context.loc.mnemonicInvalidChecksumError,
    MnemonicEntryUnknownWordFailure() => context.loc.mnemonicUnknownWordError,
    // Never `logMessage`: generic message only, per rule #11.
    MnemonicEntryUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
