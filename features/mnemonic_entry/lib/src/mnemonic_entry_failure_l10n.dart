import '../generated/l10n/mnemonic_entry_localizations.dart';
import 'mnemonic_entry_failure.dart';

/// The only place a [MnemonicEntryFailure] becomes a user-facing string, so the
/// failure family itself stays Flutter-free. The `sealed` switch makes a missing
/// message a compile error.
extension MnemonicEntryFailureL10n on MnemonicEntryFailure {
  String toTranslated(MnemonicEntryLocalizations labels) => switch (this) {
    MnemonicEntryIncompleteFailure() => labels.emptyMnemonicWordsError,
    MnemonicEntryInvalidChecksumFailure() =>
      labels.mnemonicInvalidChecksumError,
    MnemonicEntryUnknownWordFailure() => labels.mnemonicUnknownWordError,
    MnemonicEntryOtherLanguageFailure(:final wordlist, :final selected) =>
      labels.mnemonicOtherLanguageWordsError(
        labels.mnemonicLanguageName(wordlist.name),
        labels.mnemonicLanguageName(selected.name),
      ),
    // Never `logMessage`: generic message only, per rule #11.
    MnemonicEntryUnexpectedFailure() => labels.oopsSomethingWentWrong,
  };
}
