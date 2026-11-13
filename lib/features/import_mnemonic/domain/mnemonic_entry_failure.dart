import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// Why a typed mnemonic could not be accepted.
///
/// No variant carries a word, on purpose. The sentence being validated *is* the
/// secret, and [Failure.logMessage] is documented as going to logs and Sentry.
/// `bip39_mnemonic` builds its exception messages out of the offending word
/// (`Mnemonic word "$word" does not exist in $language`,
/// `Mnemonic checksum ${words.last} is invalid`), so those strings must be
/// dropped where the exception is caught and never forwarded into a failure.
sealed class MnemonicEntryFailure extends Failure {
  const MnemonicEntryFailure([super.logMessage]);
}

/// At least one field is still blank.
final class MnemonicEntryIncompleteFailure extends MnemonicEntryFailure {
  const MnemonicEntryIncompleteFailure();
}

/// Every word is in the wordlist, but the sentence does not close its checksum
/// — the transcription error the checksum exists to catch.
final class MnemonicEntryInvalidChecksumFailure extends MnemonicEntryFailure {
  const MnemonicEntryInvalidChecksumFailure();
}

/// At least one word is not in the wordlist of the selected language.
final class MnemonicEntryUnknownWordFailure extends MnemonicEntryFailure {
  const MnemonicEntryUnknownWordFailure();
}

/// Every word belongs to [wordlist] rather than the [selected] one, but the
/// phrase has no valid checksum in [wordlist] either. Names wordlists only.
final class MnemonicEntryOtherLanguageFailure extends MnemonicEntryFailure {
  final bip39.Language wordlist;
  final bip39.Language selected;

  const MnemonicEntryOtherLanguageFailure({
    required this.wordlist,
    required this.selected,
  });
}

/// Catch-all. [logMessage] holds the exception's *runtime type only* — never
/// its message, which would carry a word.
final class MnemonicEntryUnexpectedFailure extends MnemonicEntryFailure {
  const MnemonicEntryUnexpectedFailure([super.logMessage]);
}
