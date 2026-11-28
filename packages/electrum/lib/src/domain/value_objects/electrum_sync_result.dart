import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

class ElectrumSyncResult {
  final WalletKey key;
  final int runId;
  final bool isLiquid;
  final bool success;

  const ElectrumSyncResult({
    required this.key,
    required this.runId,
    required this.isLiquid,
    required this.success,
  });

  /// Projects server reachability without reporting a busy writer or a
  /// deferred initial scan as a connection failure.
  static Stream<ElectrumSyncResult> watch(Stream<SyncFinished> completions) =>
      completions
          .where(
            (event) => switch (event.result) {
              Err(
                failure: SyncBusyFailure() || SyncInitialScanRequiredFailure(),
              ) =>
                false,
              _ => true,
            },
          )
          .map(
            (event) => ElectrumSyncResult(
              key: event.key,
              runId: event.runId,
              isLiquid: event.key.network is LiquidNetwork,
              success: event.result is Ok<SyncCompletion, SyncFailure>,
            ),
          );
}
