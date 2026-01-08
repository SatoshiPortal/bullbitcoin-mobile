import 'package:meta/meta.dart';

@immutable
sealed class SeedSecret {
  const SeedSecret();
  SeedSecretKind get kind;
}

enum SeedSecretKind { bytes, mnemonic }

@immutable
class SeedBytesSecret extends SeedSecret {
  final List<int> bytes;
  const SeedBytesSecret(this.bytes);
  @override
  SeedSecretKind get kind => SeedSecretKind.bytes;
}

@immutable
class SeedMnemonicSecret extends SeedSecret {
  final List<String> words;
  final String? passphrase;

  const SeedMnemonicSecret({required this.words, this.passphrase});

  @override
  SeedSecretKind get kind => SeedSecretKind.mnemonic;

  @override
  // **redacted** to avoid accidental leaking sensitive information in logs
  String toString() => 'SeedMnemonicSecret(**redacted**)';
}
