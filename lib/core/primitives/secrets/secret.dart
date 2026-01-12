import 'package:meta/meta.dart';

@immutable
sealed class Secret {
  const Secret();
  SecretKind get kind;
}

enum SecretKind { seed, mnemonic }

@immutable
class SeedSecret extends Secret {
  final List<int> bytes;
  const SeedSecret(this.bytes);
  @override
  SecretKind get kind => SecretKind.seed;
}

@immutable
class MnemonicSecret extends Secret {
  final List<String> words;
  final String? passphrase;

  const MnemonicSecret({required this.words, this.passphrase});

  @override
  SecretKind get kind => SecretKind.mnemonic;

  @override
  // **redacted** to avoid accidental leaking sensitive information in logs
  String toString() => 'MnemonicSecret(**redacted**)';
}
