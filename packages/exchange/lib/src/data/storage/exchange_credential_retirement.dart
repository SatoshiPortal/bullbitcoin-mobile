import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';

/// Read-only retirement proof for Exchange. The encrypted destination receipt
/// is checked by the coordinator. No keychain entries are read or deleted.
final class ExchangeCredentialRetirement
    implements LegacyRetirementParticipant {
  const ExchangeCredentialRetirement();

  @override
  String get ownerId => 'exchange';

  @override
  Future<Result<void, LegacyImportFailure>> verifyRetirable(
    ExclusiveAdmission admission, {
    required OwnerOrigin origin,
    required LegacySource source,
  }) async =>
      admission.isOpen ? const Ok(null) : const Err(LegacyImportDeferred());
}
