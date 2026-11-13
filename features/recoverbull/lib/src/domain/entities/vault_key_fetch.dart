import 'package:secrets/secrets.dart' show VaultKey;

import 'attempt_observation.dart';

final class VaultKeyFetch {
  final VaultKey key;
  final AttemptObservation? observation;

  const VaultKeyFetch(this.key, this.observation);
}
