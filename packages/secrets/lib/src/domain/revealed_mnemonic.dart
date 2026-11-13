import 'package:meta/meta.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;

/// Why key material is being exposed.
///
/// Required by [SecretReveal.words] so every reveal names itself at the
/// call site, and the audit is a grep rather than a reading of the app.
enum RevealReason {
  /// The user asked to see their own words on screen.
  userDisplay,

  /// Checking a physical backup the user typed back in. Prefer
  /// [Secret.verifyWords], which compares without exposing anything.
  physicalBackupCheck,
}

/// A mnemonic as the user must write it down.
///
/// The passphrase belongs with the words: a backup missing it does not
/// restore the wallet, and every screen that shows one shows both.
final class RevealedMnemonic {
  final List<String> words;

  /// The wordlist read with these words, not a handle metadata snapshot.
  final Language language;

  /// Empty when there is none.
  final String passphrase;

  @internal
  const RevealedMnemonic({
    required this.words,
    required this.language,
    required this.passphrase,
  });

  bool get hasPassphrase => passphrase.isNotEmpty;

  @override
  String toString() => 'RevealedMnemonic(${words.length} words, •••)';
}
