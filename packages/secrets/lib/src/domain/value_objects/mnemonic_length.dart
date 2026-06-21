/// Supported mnemonic word counts. `generateMnemonic` defaults to [words12]
/// (matches the app's current `MnemonicGenerator`).
enum MnemonicLength {
  words12(12),
  words24(24);

  const MnemonicLength(this.words);
  final int words;

  static MnemonicLength fromCount(int count) => switch (count) {
        12 => MnemonicLength.words12,
        24 => MnemonicLength.words24,
        _ => throw ArgumentError.value(
            count, 'count', 'Unsupported mnemonic length'),
      };
}
