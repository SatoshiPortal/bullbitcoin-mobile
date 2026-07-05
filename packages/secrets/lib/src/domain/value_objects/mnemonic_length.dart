import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';
import 'package:secrets/src/domain/secrets_error.dart';

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
        _ => throw UnsupportedMnemonicLengthError(
            'Unsupported mnemonic length', 'count'),
      };

  /// The matching `bip39_mnemonic` length. `@internal` so the public API never
  /// leaks the third-party enum — callers use [MnemonicLength]; only the
  /// package's adapters map across this single point.
  @internal
  bip39.MnemonicLength get asBip39 => this == MnemonicLength.words12
      ? bip39.MnemonicLength.words12
      : bip39.MnemonicLength.words24;
}
