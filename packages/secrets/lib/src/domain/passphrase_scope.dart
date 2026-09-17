/// An output, and whether the secret's passphrase took part in producing it.
///
/// Two operations derive from the BIP39 words alone — the RecoverBull vault, whose format has no passphrase field, and the Liquid descriptor, which lwk derives without one. For a secret that *has* a passphrase, what they produce belongs to its passphrase-less sibling: a different wallet, with no error. This type is how that is said, and it is `sealed` so a caller cannot reach the value without meeting the case where it matters.
///
/// A secret with no passphrase always yields [WholeSecret]: there is nothing to leave out. See the README, § Passphrase.
///
/// The value lives on the variants, not here — a `.value` on the base would let a caller skip the `switch`, and then the type would say nothing (Codex, D6, 2026-09-16).
sealed class PassphraseScope<T> {
  const PassphraseScope();
}

/// Everything the secret is took part. Either it has no passphrase, or the operation used it.
final class WholeSecret<T> extends PassphraseScope<T> {
  final T value;
  const WholeSecret(this.value);
}

/// Derived from the words alone, while the secret **has** a passphrase.
///
/// Whatever the user does with [value], it addresses the passphrase-less
/// wallet. Tell them so: a backup restored from it, or funds sent to an
/// address derived from it, belong to a wallet they did not mean.
final class WordsOnly<T> extends PassphraseScope<T> {
  final T value;
  const WordsOnly(this.value);
}
