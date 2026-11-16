import 'package:primitives/primitives.dart';

import '../../../ark.dart';

// Private construction contract. Never export proof/preimage data through ark.dart.
enum ArkExitCaptureState { dirty, incomplete, current }

enum ArkExitWitnessState { unknown, missing, complete }

enum ArkExitProofLife { active, pending, uncertain, superseded, chainSpent }

enum ArkExitCaptureStage {
  open,
  synchronize,
  payment,
  receive,
  renewal,
  board,
  exit,
  claim,
  reconcile,
  catchUp,
}

enum ArkExitCaptureIssue {
  nativeCoverageUnavailable,
  witnessUnavailable,
  keyIndexUnavailable,
  secretUnavailable,
  identityUnavailable,
  nativeOutcomeUncertain,
  restoreUnsupported,
  captureFailed,
}

final class ArkExitArchiveIdentity {
  /// Durable archive instance identifier; persist once, never derive from sequence.
  final String archiveId;
  final ArkAccountId account;
  final String nativeVersion;
  final String derivationProfile;
  ArkExitArchiveIdentity(
    this.account,
    this.nativeVersion,
    this.derivationProfile, {
    required this.archiveId,
  });

  bool matches(ArkExitArchiveIdentity other) =>
      archiveId == other.archiveId &&
      account == other.account &&
      nativeVersion == other.nativeVersion &&
      derivationProfile == other.derivationProfile;
}

final class ArkExitProofVersion {
  final String vtxoId;
  final String proofHash;
  final String fullHex;
  final int encodingVersion;
  final String? serverKey;
  final String? checkpointId;
  final ArkExitWitnessState witnesses;
  ArkExitProofVersion({
    required this.vtxoId,
    required this.proofHash,
    required this.fullHex,
    required this.encodingVersion,
    this.serverKey,
    this.checkpointId,
    this.witnesses = ArkExitWitnessState.unknown,
  });
}

final class ArkExitProofHead {
  final String vtxoId;
  final String proofHash;
  final ArkExitProofLife life;
  final String? evidenceReference;
  ArkExitProofHead(
    this.vtxoId,
    this.proofHash,
    this.life, {
    this.evidenceReference,
  });
}

/// Secret-bearing internal value; default Object.toString does not dump fields.
final class ArkExitClaimMaterial {
  final String id;
  final String? vtxoId;
  final String? publicKey;
  final int? keyIndex;
  final bool indexVerified;
  final String? paymentHash;
  final String? preimage;
  ArkExitClaimMaterial({
    required this.id,
    this.vtxoId,
    this.publicKey,
    this.keyIndex,
    this.indexVerified = false,
    this.paymentHash,
    this.preimage,
  });
}

final class ArkExitCaptureIntent {
  final ArkExitArchiveIdentity archive;
  final int sequence;
  final ArkExitCaptureStage stage;
  final String? operationId;
  final int? sourceRevision;
  final List<String> knownInputs;
  ArkExitCaptureIntent(
    this.archive,
    this.sequence,
    this.stage, {
    this.operationId,
    this.sourceRevision,
    List<String> knownInputs = const [],
  }) : knownInputs = List.unmodifiable(knownInputs);

  /// Compare the complete durable record, including after SQLite reconstruction.
  bool matches(ArkExitCaptureIntent other) =>
      archive.matches(other.archive) &&
      sequence == other.sequence &&
      stage == other.stage &&
      operationId == other.operationId &&
      sourceRevision == other.sourceRevision &&
      knownInputs.length == other.knownInputs.length &&
      Iterable<int>.generate(knownInputs.length)
          .every((i) => knownInputs[i] == other.knownInputs[i]);
}

final class ArkExitCaptureBatch {
  final List<ArkExitProofVersion> proofs;
  final List<ArkExitProofHead> heads;
  final List<ArkExitClaimMaterial> material;

  /// Additive unresolved issues. Empty never clears retained gaps.
  final Set<ArkExitCaptureIssue> issues;

  /// Trusted local exporter coverage, never inferred from ordinary allVtxos.
  /// Current pin cannot assert checkpoint/witness/index coverage: leave null.
  final int? coveredThrough;
  ArkExitCaptureBatch({
    List<ArkExitProofVersion> proofs = const [],
    List<ArkExitProofHead> heads = const [],
    List<ArkExitClaimMaterial> material = const [],
    Set<ArkExitCaptureIssue> issues = const {
      ArkExitCaptureIssue.nativeCoverageUnavailable,
    },
    this.coveredThrough,
  }) : proofs = List.unmodifiable(proofs),
       heads = List.unmodifiable(heads),
       material = List.unmodifiable(material),
       issues = Set.unmodifiable(issues);
}

final class ArkExitArchiveView {
  final ArkExitArchiveIdentity identity;
  final int sequence;
  final int acknowledgedThrough;
  final ArkExitCaptureState state;
  final Set<ArkExitCaptureIssue> issues;
  final List<ArkExitProofVersion> proofs;
  final List<ArkExitProofHead> heads;
  final List<ArkExitClaimMaterial> material;
  final List<ArkExitCaptureIntent> pending;
  ArkExitArchiveView({
    required this.identity,
    required this.sequence,
    required this.acknowledgedThrough,
    required this.state,
    required Set<ArkExitCaptureIssue> issues,
    required List<ArkExitProofVersion> proofs,
    required List<ArkExitProofHead> heads,
    required List<ArkExitClaimMaterial> material,
    required List<ArkExitCaptureIntent> pending,
  }) : issues = Set.unmodifiable(issues),
       proofs = List.unmodifiable(proofs),
       heads = List.unmodifiable(heads),
       material = List.unmodifiable(material),
       pending = List.unmodifiable(pending);
}

/// Five-table, account-private evidence archive, called only under Ark writer.
/// begin commits dirty BEFORE native admission. commit is one archive transaction;
/// failure retains the original dirty intent/old proofs. No financial authority.
///
/// Opening binds the durable archive/account/profile/format without reset.
/// commit/failed compare the full stored intent, not Dart object identity.
/// Proof bytes/hash/encoding are immutable; equal bytes may refine unknown
/// qualification, but contradictory missing/complete evidence refuses. Lower
/// information never erases a qualification, checkpoint, preimage or index.
/// Heads reference retained proofs; retirement requires exact positive producer
/// evidence. Material identities bind their VTXO/key/hash role; collisions refuse.
///
/// Coverage is trusted capture evidence, never spending or retirement authority.
/// Null does not acknowledge. Non-null cannot regress, be negative or exceed
/// this intent; partial observation cannot close earlier unresolved mutations.
/// Retained missing/unknown witness, index, secret, checkpoint or validation gaps
/// prevent acknowledgement/current. Current means proved capture AND readiness,
/// not merely opaque bytes or empty inventory. The pinned exporter cannot prove
/// this coverage: it always leaves coveredThrough null and retains native gaps.
/// All merges, issues, acknowledgement and state commit in one transaction.
/// failed only adds an issue; read/commit/failed/begin after close refuse storage.
/// close drains admitted work, owning only archive resources, never native work.
abstract interface class ArkExitArchive {
  Future<Result<ArkExitCaptureIntent, ArkWalletFailure>> begin(
    ArkExitCaptureStage stage, {
    String? operationId,
    int? sourceRevision,
    List<String> knownInputs = const [],
  });
  Future<Result<void, ArkWalletFailure>> commit(
    ArkExitCaptureIntent intent,
    ArkExitCaptureBatch batch,
  );
  Future<Result<void, ArkWalletFailure>> failed(ArkExitCaptureIntent intent);
  Future<Result<ArkExitArchiveView, ArkWalletFailure>> read();
  Future<void> close();
}
