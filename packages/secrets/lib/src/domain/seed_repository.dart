import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'secrets_failure.dart';
import 'value_objects/mnemonic_length.dart';
import 'value_objects/seed_info.dart';

/// The ONLY Repository in `secrets` — the seed lifecycle. Every method returns
/// the canonical `Result<_, SecretsFailure>`; none throw recoverable exceptions
/// across this boundary. `get`/`getAllMnemonicSeeds` are deliberately absent:
/// no seed entity escapes — callers get non-secret [SeedInfo] only.
abstract interface class SeedRepository {
  @useResult
  Future<Result<Fingerprint, SecretsFailure>> importMnemonic({
    required List<String> words,
    String? passphrase,
  });

  @useResult
  Future<Result<Fingerprint, SecretsFailure>> generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  });

  @useResult
  Future<Result<Fingerprint, SecretsFailure>> importBytes(Uint8List bytes);

  /// Trust-gated: the caller is responsible for a confirmed use-case (a public
  /// [Fingerprint] conveys identity, not authority).
  @useResult
  Future<Result<void, SecretsFailure>> delete(Fingerprint fp);

  @useResult
  Future<Result<bool, SecretsFailure>> exists(Fingerprint fp);

  @useResult
  Future<Result<List<SeedInfo>, SecretsFailure>> listSeeds();

  @useResult
  Future<Result<SeedInfo?, SecretsFailure>> getInfo(Fingerprint fp);

  /// Derives the fingerprint WITHOUT storing (e.g. duplicate pre-check).
  @useResult
  Future<Result<Fingerprint, SecretsFailure>> fingerprintOf({
    required List<String> words,
    String? passphrase,
  });
}
