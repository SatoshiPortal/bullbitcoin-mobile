import 'package:bb_mobile/core/failures/failure.dart';

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

/// Catch-all. [logMessage] holds the exception's *runtime type only* — never
/// its message, which would carry a word.
final class MnemonicEntryUnexpectedFailure extends MnemonicEntryFailure {
  const MnemonicEntryUnexpectedFailure([super.logMessage]);
}
