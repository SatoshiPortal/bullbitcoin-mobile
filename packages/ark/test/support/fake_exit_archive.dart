import 'package:ark/ark.dart';
import 'package:ark/src/data/exit_archive/ark_exit_archive.dart';
import 'package:primitives/primitives.dart';

/// Recording-only consumer fake. It cannot validate proof/material merges or
/// complete coverage; use the real SQLite store for invariant/restart tests.
final class FakeExitArchive implements ArkExitArchive {
  final ArkExitArchiveIdentity identity;
  final List<ArkExitCaptureIntent> begins = [];
  final List<ArkExitCaptureBatch> commits = [];
  final Map<int, ArkExitCaptureIntent> _pending = {};
  final Set<ArkExitCaptureIssue> _issues = {
    ArkExitCaptureIssue.nativeCoverageUnavailable,
  };
  int _sequence = 0;
  bool failCommit = false;
  bool closed = false;
  FakeExitArchive(this.identity);

  @override
  Future<Result<ArkExitCaptureIntent, ArkWalletFailure>> begin(
    ArkExitCaptureStage stage, {
    String? operationId,
    int? sourceRevision,
    List<String> knownInputs = const [],
  }) async {
    if (closed) return const Err(ArkStorageFailure());
    final intent = ArkExitCaptureIntent(
      identity,
      ++_sequence,
      stage,
      operationId: operationId,
      sourceRevision: sourceRevision,
      knownInputs: knownInputs,
    );
    begins.add(intent);
    _pending[intent.sequence] = intent;
    return Ok(intent);
  }

  @override
  Future<Result<void, ArkWalletFailure>> commit(
    ArkExitCaptureIntent intent,
    ArkExitCaptureBatch batch,
  ) async {
    if (closed || failCommit) return const Err(ArkStorageFailure());
    final stored = _pending[intent.sequence];
    if (stored == null ||
        !stored.matches(intent) ||
        batch.coveredThrough != null) {
      return const Err(ArkValidationFailure());
    }
    commits.add(batch);
    _issues.addAll(batch.issues);
    return const Ok(null);
  }

  @override
  Future<Result<void, ArkWalletFailure>> failed(
    ArkExitCaptureIntent intent,
  ) async {
    if (closed) return const Err(ArkStorageFailure());
    final stored = _pending[intent.sequence];
    if (stored == null || !stored.matches(intent)) {
      return const Err(ArkValidationFailure());
    }
    _issues.add(ArkExitCaptureIssue.captureFailed);
    return const Ok(null);
  }

  @override
  Future<Result<ArkExitArchiveView, ArkWalletFailure>> read() async => closed
      ? const Err(ArkStorageFailure())
      : Ok(
          ArkExitArchiveView(
            identity: identity,
            sequence: _sequence,
            acknowledgedThrough: 0,
            state: _pending.isNotEmpty
                ? ArkExitCaptureState.dirty
                : ArkExitCaptureState.incomplete,
            issues: _issues,
            proofs: const [],
            heads: const [],
            material: const [],
            pending: _pending.values.toList(),
          ),
        );
  @override
  Future<void> close() async {
    closed = true;
  }
}
