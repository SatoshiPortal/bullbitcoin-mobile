import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart';

/// An independent, unstored mnemonic retained only for a bounded setup flow.
/// Dispose it when that flow ends. Words are available only to the sealed widgets.
final class EphemeralMnemonic {
  final EphemeralMnemonicRepository _repository;

  @internal
  const EphemeralMnemonic(EphemeralMnemonicRepository repository)
    : _repository = repository;

  Fingerprint get id => _repository.id;
  int get wordCount => _repository.wordCount;

  @useResult
  Future<Result<PublicAccountKey, SecretFailure>> account({
    required String derivationPath,
    required BitcoinNetwork network,
  }) => _repository.account(derivationPath: derivationPath, network: network);

  void dispose() => _repository.dispose();

  @internal
  Future<Result<RevealedMnemonic, SecretFailure>> revealMnemonic({
    required RevealReason reason,
  }) => _repository.reveal();

  @internal
  Future<Result<bool, SecretFailure>> verifyWords(List<String> words) =>
      _repository.verify(words);

  @override
  String toString() => 'EphemeralMnemonic($wordCount words)';
}
