import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import '../background_tasks_failure.dart';
import '../wallet_sync_chain.dart';
import '../wallet_sync_job_claim.dart';

/// Which wallet to sync next, with leases so two runs never work on the
/// same wallet. Native exclusion still belongs to the writer.
abstract interface class WalletSyncJobQueueRepository {
  Duration get leaseDuration;

  /// Records the current catalog stamps of [chain], then claims up to
  /// [maxJobs] due jobs, never one in [excluding] or [unavailable].
  @useResult
  Future<Result<List<WalletSyncJobClaim>, BackgroundTasksFailure>>
  reconcileAndClaim(
    Iterable<WalletRevision> jobs, {
    required WalletSyncChain chain,
    int maxJobs = 2,
    Iterable<WalletKey> excluding = const [],
    Iterable<WalletKey> unavailable = const [],
  });

  @useResult
  Future<Result<void, BackgroundTasksFailure>> renew(WalletSyncJobClaim claim);

  @useResult
  Future<Result<void, BackgroundTasksFailure>> completeSuccess(
    WalletSyncJobClaim claim,
  );

  @useResult
  Future<Result<void, BackgroundTasksFailure>> completeFailure(
    WalletSyncJobClaim claim, {
    required bool permanent,
    WalletRevision? failedRevision,
  });

  /// Gives back a claim that was never worked on: it is claimable again at
  /// once and its claim does not count as an attempt.
  @useResult
  Future<Result<void, BackgroundTasksFailure>> release(
    WalletSyncJobClaim claim,
  );

  Future<void> close();
}
