import 'package:bb_mobile/features/import_mnemonic/domain/mnemonic_entry_failure.dart';
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
    MnemonicEntryOtherLanguageFailure(:final wordlist, :final selected) =>
      context.loc.mnemonicOtherLanguageWordsError(
        context.loc.mnemonicLanguageName(wordlist.name),
        context.loc.mnemonicLanguageName(selected.name),
      ),
    // Never `logMessage`: generic message only, per rule #11.
    MnemonicEntryUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
