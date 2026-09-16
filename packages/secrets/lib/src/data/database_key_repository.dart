import 'dart:math';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/src/data/models/key_model.dart';
import 'package:secrets/src/domain/domain.dart';

/// The encryption keys this package holds on other modules' behalf.
///
/// A repository by role — it mediates between the stored envelope and the `DatabaseKey` a module uses — and named as the codebase names that role. Separate from `SecretRepository` because it shares nothing with it: no identity to derive, no PBKDF2, no format older than this package. Atomicity of read-or-create lives one layer down, in [FlutterSecureStorageDatasource.fetchOrCreateModuleKey].
class DatabaseKeyRepository {
  /// What these keys are for, and the first segment of their storage key. A read refuses to hand a database key to something asking for another kind.
  static const _kind = KeyKind.dek;

  final _source = FlutterSecureStorageDatasource();

  DatabaseKeyRepository();

  /// The database key for one package, generated on first ask.
  ///
  /// Random rather than derived from a seed, on purpose. Deriving would
  /// mean materialising the user's seed — PBKDF2, isolate, key material
  /// in memory — every time a module opens a local cache, which is the
  /// opposite of what this package exists to reduce. A random key also
  /// revokes: replace it and re-key one database, without touching the
  /// seed. And a local database that is lost with the app sandbox is not
  /// recoverable by any key, derived or not, so determinism buys
  /// nothing here.
  Future<Result<DatabaseKey, SecretFailure>> forModule({
    required String package,
    required String name,
  }) => boundary(() async {
    final model = await _source.fetchOrCreateModuleKey(
      kind: _kind,
      package: package,
      name: name,
      generateHex: () => DatabaseKey(_randomBytes()).hex,
    );
    return DatabaseKey.fromHex(model.bytesHex);
  }, orElse: SecretStoreFailure.new);

  /// Discards one module's key. Destructive: the database it encrypted can never be opened again, so the caller must drop that database in the same step. Never called by recovery code; a corrupt key is refused, not replaced (see [FlutterSecureStorageDatasource.fetchOrCreateModuleKey]).
  Future<Result<void, SecretFailure>> reset({
    required String package,
    required String name,
  }) => boundary(
    () => _source.deleteModuleKey(kind: _kind, package: package, name: name),
    orElse: SecretDeleteFailure.new,
  );

  static final _random = Random.secure();

  static Uint8List _randomBytes() => Uint8List.fromList(
    List<int>.generate(
      DatabaseKey.lengthInBytes,
      // The platform CSPRNG: /dev/urandom on Android and Linux,
      // SecRandomCopyBytes on Apple.
      (_) => _random.nextInt(256),
    ),
  );
}
