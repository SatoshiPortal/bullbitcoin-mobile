import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:wallet/wallet.dart';

/// Builds the foreground [SyncCoordinator] over the wallet use cases.
///
/// Foreground-only. The background-task isolate uses its own GetIt and must
/// not register the coordinator (its lifecycle listener has no widget binding
/// to attach to in that isolate).
///
/// [syncSp] is a lazy closure resolved at call time, like the swap callbacks,
/// so the coordinator never imports the SP feature.
SyncCoordinator createForegroundSyncCoordinator({
  required GetWalletsUsecase getWalletsUsecase,
  required SyncWalletUsecase syncWalletUsecase,
  Future<void> Function()? syncSwaps,
  Future<SyncOutcome> Function()? syncSwapsOutcome,
  Future<void> Function()? syncSp,
}) {
  /// Syncs every wallet the read returns, or returns the read's failure so the
  /// round fails.
  ///
  /// Deliberately not degraded to an empty list: the coordinator stamps its
  /// last success for any round that completes normally, so a swallowed read
  /// failure would both report a successful sync to pull-to-refresh and count
  /// toward the throttle, suppressing the retries that would recover from a
  /// transient failure.
  Future<WalletFailure?> syncAll(
    Future<Result<List<Wallet>, WalletFailure>> read, {
    required bool discover,
  }) async {
    switch (await read) {
      case Ok(:final value):
        for (final wallet in value) {
          await syncWalletUsecase.execute(wallet, discoverHistory: discover);
        }
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  return SyncCoordinator(
    syncBitcoin: ({required discover}) => syncAll(
      getWalletsUsecase.execute(onlyBitcoin: true),
      discover: discover,
    ),
    syncLiquid: ({required discover}) => syncAll(
      getWalletsUsecase.execute(onlyLiquid: true),
      discover: discover,
    ),
    syncSwaps: syncSwaps,
    syncSwapsOutcome: syncSwapsOutcome,
    syncSp: syncSp,
    // No wallet yet is the normal state before onboarding, not a broken sync.
    isRoutineFailure: (failure) => failure is NoWalletsFoundFailure,
  );
}

/// Synchronizes one wallet from a background task over the user's Electrum
/// servers, falling back between them as the foreground does. A server that is
/// unavailable is transient and tries the next one; once all fail, the run
/// reports the source unavailable.
Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
synchronizeWalletInBackground({
  required WalletModel model,
  required WalletNetworkKey key,
  required WalletTransactionSyncFacade facade,
  required ElectrumServersPort servers,
}) async {
  final network = ElectrumServerNetwork.fromEnvironment(
    isTestnet: model.isTestnet,
    isLiquid: model is PublicLwkWalletModel,
  );
  try {
    return await servers.runWithFallback(
      network: network,
      isTransient: (error) => error is _TransientBackgroundSync,
      operation: (connection) async {
        final configuration = model is PublicBdkWalletModel
            ? BdkElectrumConfiguration(
                externalPublicDescriptor: model.externalDescriptor,
                internalPublicDescriptor: model.internalDescriptor,
                isTestnet: model.isTestnet,
                electrumUrls: [connection.url],
                stopGap: connection.stopGap,
                validateDomain: connection.validateDomain,
                databaseFilePath: p.join(
                  (await getApplicationDocumentsDirectory()).path,
                  '${model.hexId}_bdk_dart',
                ),
                socks5: connection.socks5,
                timeout: connection.effectiveTimeout,
                retry: connection.retry,
              )
            : LwkElectrumConfiguration(
                confidentialPublicDescriptor:
                    (model as PublicLwkWalletModel).combinedCtDescriptor,
                isTestnet: model.isTestnet,
                electrumUrls: [connection.url],
                validateDomain: connection.validateDomain,
                databaseRootPath: p.join(
                  (await getApplicationDocumentsDirectory()).path,
                  model.hexId,
                ),
                timeout: connection.effectiveTimeout,
                stopAtIndex: connection.stopGap,
              );
        final registration = WalletSourceRegistration.withFingerprint(
          key: key,
          sourceKind: model is PublicLwkWalletModel
              ? 'lwk_electrum'
              : 'bdk_electrum',
          configuration: configuration,
        );
        final result = await facade.synchronizeWallet(
          SynchronizeWalletRequest(
            registration,
            priority: WalletOperationPriority.background,
            allowInitialScan: false,
          ),
        );
        if (result case Err(:final failure)
            when failure is SourceFailure &&
                failure.reason == SourceFailureReason.unavailable) {
          throw const _TransientBackgroundSync();
        }
        return result;
      },
    );
  } on Exception {
    return const Err(SourceFailure(SourceFailureReason.unavailable));
  }
}

final class _TransientBackgroundSync implements Exception {
  const _TransientBackgroundSync();
}
