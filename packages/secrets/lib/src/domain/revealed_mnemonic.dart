import 'package:meta/meta.dart';

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

  /// Empty when there is none.
  final String passphrase;

  @internal
  const RevealedMnemonic({required this.words, required this.passphrase});

  bool get hasPassphrase => passphrase.isNotEmpty;

  @override
  String toString() => 'RevealedMnemonic(${words.length} words, •••)';
}
