import 'package:primitives/primitives.dart';

import '../domain/bip85_derivation_entity.dart';
import '../domain/errors/bip85_failure.dart';

export '../domain/bip85_derivation_entity.dart';
export '../domain/errors/bip85_failure.dart';

/// Read-only historical inventory, including revoked derivations.
final class Bip85Registry {
  final Future<Result<List<Bip85DerivationEntity>, Bip85Failure>> Function()
  _read;

  const Bip85Registry(this._read);

  Future<Result<List<Bip85DerivationEntity>, Bip85Failure>> fetchAll() =>
      _read();
}
