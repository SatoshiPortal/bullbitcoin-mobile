import 'package:primitives/primitives.dart';
import 'package:secrets/bip85.dart';

import '../domain/ark_child_collision_port.dart';
import '../domain/ark_failure.dart';

/// Reads every historical BIP85 record, including revoked derivations.
final class ArkDerivationCollision implements ArkChildCollisionPort {
  final Bip85Derivations _registry;
  const ArkDerivationCollision(this._registry);

  @override
  Future<Result<bool, ArkFailure>> hasCollision(Fingerprint parent) async {
    switch (await _registry.list()) {
      case Err():
        return const Err(ArkFeatureStorageFailure());
      case Ok(:final value):
        for (final record in value) {
          final owner = Fingerprint.tryParse(
            record.parentFingerprint.toLowerCase(),
          );
          if (owner == null) return const Err(ArkFeatureStorageFailure());
          if (owner == parent && record.application == Bip85Application.bip39) {
            // The existing datasource stores the four hardened application
            // components without the common BIP85 root prefix. An unknown
            // representation cannot certify that this child is unused.
            if (record.path.length > 128) {
              return const Err(ArkFeatureStorageFailure());
            }
            final path = RegExp(r"^39'/([0-9]+)'/([0-9]+)'/([0-9]+)'$")
                .firstMatch(record.path);
            if (path == null) return const Err(ArkFeatureStorageFailure());
            final language = int.tryParse(path.group(1) ?? '');
            final words = int.tryParse(path.group(2) ?? '');
            final index = int.tryParse(path.group(3) ?? '');
            if (language == null ||
                words == null ||
                index == null ||
                language > 0x7fffffff ||
                index > 0x7fffffff ||
                !const {12, 15, 18, 21, 24}.contains(words)) {
              return const Err(ArkFeatureStorageFailure());
            }
            if (language == 0 && words == 12 && index == 11811) {
              return const Ok(true);
            }
          }
        }
        return const Ok(false);
    }
  }
}
