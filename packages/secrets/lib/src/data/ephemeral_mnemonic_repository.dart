import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart';
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/domain/domain.dart';

/// Owns an independent mnemonic for one display-and-verification session.
final class EphemeralMnemonicRepository {
  final Fingerprint id;
  final int wordCount;
  List<String>? _words;

  EphemeralMnemonicRepository._(this.id, List<String> words)
    : wordCount = words.length,
      _words = words;

  static Future<Result<EphemeralMnemonicRepository, SecretFailure>> generate(
    MnemonicLength wordCount,
  ) => boundary(() async {
    final words = Generator.mnemonic(wordCount: wordCount);
    final bytes = Deriver.fingerprint.seed(words);
    try {
      return EphemeralMnemonicRepository._(
        Deriver.fingerprint.fingerprint(bytes),
        words,
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }, orElse: UseSecretFailure.new);

  Future<Result<RevealedMnemonic, SecretFailure>> reveal() => boundary(
    () async => RevealedMnemonic(
      words: List<String>.unmodifiable(_availableWords()),
      language: Language.english,
      passphrase: '',
    ),
    orElse: UseSecretFailure.new,
  );

  Future<Result<bool, SecretFailure>> verify(List<String> candidate) {
    final copy = List<String>.of(candidate);
    return boundary(() async {
      final words = _availableWords();
      if (copy.length != words.length) return false;
      var matches = true;
      for (var i = 0; i < words.length; i++) {
        if (words[i] != copy[i]) matches = false;
      }
      return matches;
    }, orElse: UseSecretFailure.new);
  }

  Future<Result<PublicAccountKey, SecretFailure>> account({
    required String derivationPath,
    required BitcoinNetwork network,
  }) => boundary(() async {
    final bytes = Deriver.fingerprint.seed(_availableWords());
    try {
      return Deriver.bitcoin.account(
        Seed(id: id, seedBytes: bytes),
        derivationPath: derivationPath,
        network: network,
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }, orElse: UseSecretFailure.new);

  void dispose() {
    _words?.clear();
    _words = null;
  }

  List<String> _availableWords() {
    final words = _words;
    if (words == null) throw const FormatException('Mnemonic session closed');
    return words;
  }
}
