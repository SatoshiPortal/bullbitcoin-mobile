import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/ephemeral_mnemonic.dart';
import 'package:secrets/src/public/extensions.dart';
import 'package:secrets/src/public/secret.dart';

/// Package-internal access shared by stored and temporary mnemonic widgets.
sealed class MnemonicSource {
  @internal
  const MnemonicSource();

  Fingerprint get id;
  int get wordCount;
  Future<Result<RevealedMnemonic, SecretFailure>> reveal(RevealReason reason);
  Future<Result<bool, SecretFailure>> verify(List<String> words);
}

final class StoredMnemonicSource extends MnemonicSource {
  final Secret _secret;

  @internal
  const StoredMnemonicSource(this._secret);

  @override
  Fingerprint get id => _secret.id;
  @override
  int get wordCount => _secret.info.wordCount ?? 0;
  @override
  Future<Result<RevealedMnemonic, SecretFailure>> reveal(RevealReason reason) =>
      _secret.revealMnemonic(reason: reason);
  @override
  Future<Result<bool, SecretFailure>> verify(List<String> words) =>
      _secret.verify.mnemonic(words);
}

final class EphemeralMnemonicSource extends MnemonicSource {
  final EphemeralMnemonic _mnemonic;

  @internal
  const EphemeralMnemonicSource(this._mnemonic);

  @override
  Fingerprint get id => _mnemonic.id;
  @override
  int get wordCount => _mnemonic.wordCount;
  @override
  Future<Result<RevealedMnemonic, SecretFailure>> reveal(RevealReason reason) =>
      _mnemonic.revealMnemonic(reason: reason);
  @override
  Future<Result<bool, SecretFailure>> verify(List<String> words) =>
      _mnemonic.verifyWords(words);
}
