import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../legacy_storage.dart';
import 'coordinator.dart';
import 'lifecycle.dart';

/// Owners whose legacy keychain entries or secondary receipts the retirement
/// gate must be able to verify before it allows the plaintext source to go.
const legacyRetirementOwners = <String>{'secrets', 'exchange', 'recoverbull'};

/// An owner that holds legacy material outside the shared legacy database.
///
/// Verification runs under the exclusive lease, never under a shared one.
/// This interface exposes no destructive operation.
abstract interface class LegacyRetirementParticipant {
  String get ownerId;

  /// Refuses unless this owner can prove its data survives the loss of the
  /// legacy source: an independent receipt, never a reconstruction. [source]
  /// is still present and is read without writing. [origin] is the durable
  /// origin recorded in the marker.
  @useResult
  Future<Result<void, LegacyImportFailure>> verifyRetirable(
    ExclusiveAdmission admission, {
    required OwnerOrigin origin,
    required LegacySource source,
  });
}

enum RetirementState { importing, retiring, retired }

/// Result of one read-only evaluation of the retirement gate.
final class RetirementReport {
  final RetirementState? state;
  final List<String> blockers;

  RetirementReport(this.state, Iterable<String> blockers)
    : blockers = List.unmodifiable(blockers);

  bool get eligible => state == RetirementState.importing && blockers.isEmpty;

  @override
  String toString() => 'RetirementReport($state, $blockers)';
}
