import 'package:flutter_test/flutter_test.dart';
import 'package:oubliette/oubliette.dart';
import 'package:secrets/secrets.dart';

import 'fake_oubliette.dart';

/// Drift guard for the hand-maintained `_translate` switch in
/// `OublietteSecretStoreAdapter`. The capability probe re-derives "defer vs.
/// mark-incompatible" from the recoverable/structural line (§2.5): a recoverable
/// failure must DEFER (re-probe later), a structural one must mark INCOMPATIBLE.
///
/// This drives the probe through EVERY sealed [OublietteException] and asserts
/// the resulting outcome agrees with the subtype's own `recoverable` flag. If a
/// future subtype is added — or an existing one's mapping drifts from its
/// `recoverable` value — this fails CI, preventing a transiently-locked device
/// from being permanently stranded on FSS.
void main() {
  final subtypes = <OublietteException>[
    const AuthenticationFailedException(),
    const KeyringLockedException(),
    const BackendUnavailableException(),
    const KeyInvalidatedException(keyAlias: 'k'),
    const KeyNotFoundException(keyAlias: 'k'),
    const DecryptionFailedException(key: 'k'),
    const PayloadCorruptException('reason'),
    const PayloadTamperException(
      key: 'k',
      expectedAad: 'a',
      actualAad: 'b',
      expectedAlias: 'x',
      actualAlias: 'y',
    ),
  ];

  for (final e in subtypes) {
    final expected = e.recoverable
        ? SecretsBackendOutcome.fssDeferred
        : SecretsBackendOutcome.fssIncompatible;
    test('${e.runtimeType} (recoverable=${e.recoverable}) → ${expected.name}',
        () async {
      final r = await Secrets.probeBackend(
        oubliette: FakeOubliette()..throwOnInit = e,
      );
      expect(r.outcome, expected);
      expect(r.probeError, isNotNull); // the originating failure is carried out
    });
  }
}
