import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:meta/meta.dart';

@immutable
sealed class Secret {
  const Secret({required this.fingerprint});

  final Fingerprint fingerprint;
}

@immutable
class SeedSecret extends Secret {
  final SeedBytes bytes;
  const SeedSecret({required super.fingerprint, required this.bytes});
}

@immutable
class MnemonicSecret extends Secret {
  final MnemonicWords words;
  final Passphrase? passphrase;

  const MnemonicSecret({
    required super.fingerprint,
    required this.words,
    this.passphrase,
  });

  @override
  // **redacted** to avoid accidental leaking sensitive information in logs
  String toString() => 'MnemonicSecret(**redacted**)';
}
