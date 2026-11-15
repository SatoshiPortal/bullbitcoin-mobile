import 'package:primitives/primitives.dart';

/// Complete seed custody references contributed by one owner.
///
/// Owners implement this contract without depending on the application wallet feature.
abstract interface class SeedReferencePort {
  /// Returns every referenced seed fingerprint, or a failure if completeness cannot be established.
  ///
  /// An empty successful result authorizes deletion only for this owner; callers must consult every registered owner and refuse deletion if any read fails.
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints();
}

/// A complete inventory of seed custody references could not be established.
final class SeedReferencesUnavailable extends Failure {
  /// Creates a failure that requires callers to preserve the seed.
  const SeedReferencesUnavailable() : super('custody references unavailable');
}
