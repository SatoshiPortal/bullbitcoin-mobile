import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../domain/ark_parent_presence_port.dart';
import '../domain/ark_failure.dart';

final class SecretsArkParentPresence implements ArkParentPresencePort {
  final Secrets _secrets;
  const SecretsArkParentPresence(this._secrets);
  @override
  Future<Result<void, ArkFailure>> verifyPresent(Fingerprint parent) async =>
      switch (await _secrets.fetch(parent)) {
        Ok() => const Ok(null),
        Err() => const Err(ArkAccountRecoveryFailure()),
      };
}
