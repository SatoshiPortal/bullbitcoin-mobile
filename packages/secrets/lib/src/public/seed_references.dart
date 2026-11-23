import 'package:primitives/primitives.dart';

import '../domain/failures.dart';
import 'parent_custody_admission.dart';
import 'secrets.dart';
import 'seed_reference_port.dart';

class SeedReferences implements SeedReferencePort {
  final List<SeedReferencePort> _owners;
  final ParentCustodyAdmissionPort admission;

  SeedReferences(SeedReferencePort walletCatalog, {required this.admission})
    : _owners = [walletCatalog];

  /// Register other custody owners in the composition root before deletion is available.
  void register(SeedReferencePort owner) => _owners.add(owner);

  /// Holds admission from complete inventory through trash and durable outcome.
  /// A failed final state write may follow a successful trash: failure does not
  /// prove that the secret is still present. Preserve the tombstone.
  Future<Result<void, ParentCustodyFailure>> deleteUnreferenced(
    Secrets secrets,
    Fingerprint parent, {
    bool reconcileBeforeDelete = false,
  }) => admission.runExclusive(parent, (lease) async {
    final ParentCustodyState state;
    switch (lease.readState()) {
      case Ok(:final value):
        state = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (state != ParentCustodyState.ready && !reconcileBeforeDelete) {
      return const Err(ParentCustodyStateFailure());
    }
    switch (await getCustodyFingerprints()) {
      case Ok(:final value) when value.contains(parent):
        return const Err(ParentCustodyReferencedFailure());
      case Err():
        return const Err(ParentCustodyInventoryFailure());
      case Ok():
    }
    // A new deliberate manual deletion is also a foreground recovery request.
    // Orphan cleanup must never silently retry a prior interrupted deletion.
    if (state != ParentCustodyState.ready) {
      switch (await secrets.fetch(parent)) {
        case Err(failure: SecretNotFoundFailure()):
          return state == ParentCustodyState.deleting
              ? lease.markDeleted()
              : const Ok(null);
        case Err():
          return const Err(ParentCustodyDeletionFailure());
        case Ok():
          if (lease.reconcilePresent() case Err(:final failure)) {
            return Err(failure);
          }
      }
    }
    if (lease.markDeleting() case Err(:final failure)) return Err(failure);
    if (await secrets.trash(parent) case Err()) {
      return const Err(ParentCustodyDeletionFailure());
    }
    if (lease.markDeleted() case Err()) {
      return const Err(ParentCustodyDeletionFailure());
    }
    return const Ok(null);
  });

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
