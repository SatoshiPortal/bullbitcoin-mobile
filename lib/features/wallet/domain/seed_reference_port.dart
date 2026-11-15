import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class SeedReferences implements SeedReferencePort {
  final List<SeedReferencePort> _owners;

  SeedReferences(SeedReferencePort walletCatalog) : _owners = [walletCatalog];

  /// Register other custody owners in the composition root before deletion is available.
  void register(SeedReferencePort owner) => _owners.add(owner);

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async {
    final fingerprints = <Fingerprint>{};
    try {
      for (final owner in List<SeedReferencePort>.of(_owners)) {
        switch (await owner.getCustodyFingerprints()) {
          case Ok(:final value):
            fingerprints.addAll(value);
          case Err():
            return const Err(SeedReferencesUnavailable());
        }
      }
      return Ok(fingerprints);
    } on Exception {
      return const Err(SeedReferencesUnavailable());
    }
  }
}
