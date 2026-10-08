/// How many words a fresh mnemonic has.
///
/// A closed set: BIP39 defines exactly these five, and `Generator` switches
/// over them exhaustively — so an unsupported count cannot be written by a
/// caller, let alone thrown at one. The public API takes this, never an
/// `int`.
enum MnemonicWordCount {
  words12(12),
  words15(15),
  words18(18),
  words21(21),
  words24(24);

  /// The number of words, for callers that need the integer back.
  final int count;

  const MnemonicWordCount(this.count);
}
