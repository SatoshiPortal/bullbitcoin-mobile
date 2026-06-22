import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

/// The seed/wallet-key-material port (the package's only "repository"). The
/// stored secret is always a mnemonic; this port imports/generates them and
/// exposes the non-secret [SeedInfo]. Every method returns the canonical
/// `Result<_, SecretsFailure>` and none throw recoverable exceptions across the
/// boundary. `get`/`getAll` are deliberately absent — no secret escapes.
abstract interface class SeedPort {
  @useResult
  Future<Result<Fingerprint, SecretsFailure>> importMnemonic({
    required List<String> words,
    String? passphrase,
    String language = 'english',
  });

  @useResult
  Future<Result<Fingerprint, SecretsFailure>> generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  });

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
    String language = 'english',
  });
}
