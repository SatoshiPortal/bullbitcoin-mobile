import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:sync/sync.dart';

import '../domain/sync_order_swaps_usecase.dart';
import 'coordinated_swap_sync.dart';
import 'sync_coordinator.dart';

/// Foreground queue and scheduling port for the mounted overview.
final class OverviewSynchronization {
  final SyncCoordinator<WalletKey, SyncFailure> coordinator;

  const OverviewSynchronization._(this.coordinator);

  SwapSyncPort get swapPolling => CoordinatedSwapSync(coordinator);

  static OverviewSynchronization open({
    required WalletInventory inventory,
    required ActiveEnvironmentReader environment,
    required WalletCatalogPort Function() catalog,
    required Future<Result<void, SyncFailure>> Function(
      PublicWalletDescriptor, {
      bool discover,
      bool allowInitialScan,
      SyncReason reason,
    })
    synchronize,
    required Future<Result<void, SyncFailure>> Function() refreshRevisions,
    required SwapActivity Function() swaps,
    required Silent Function() silent,
  }) {
    Future<NetworkEnv> activeNetwork() async =>
        switch (await environment.readActiveEnvironment()) {
          Ok(:final value) => value.networkEnv,
          Err() => throw const WalletSnapshotException(SyncStorageFailure()),
        };

    return OverviewSynchronization._(
      SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (key) => key,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        readNetwork: activeNetwork,
        getWallets: ({onlyBitcoin, onlyLiquid}) async {
          final active = await activeNetwork();
          final keys = <WalletKey>[];
          for (final network in <Network>[
            if (onlyLiquid != true)
              ...BitcoinNetwork.values.where(
                (network) => network.env == active,
              ),
            if (onlyBitcoin != true)
              ...LiquidNetwork.values.where((network) => network.env == active),
          ]) {
            switch (await inventory.walletsForNetwork(network)) {
              case Ok(:final value):
                keys.addAll(
                  value.wallets.map(
                    (wallet) =>
                        WalletKey(id: wallet.id, network: wallet.network),
                  ),
                );
              case Err(failure: UnreadableWalletFailure()):
                continue;
              case Err():
                return const Err(SyncStorageFailure());
            }
          }
          return keys.isEmpty ? const Err(SyncNotFoundFailure()) : Ok(keys);
        },
        readWallet: (id) async => (await inventory.readWallet(id))
            .map((wallet) => WalletKey(id: wallet.id, network: wallet.network))
            .mapErr((_) => const SyncNotFoundFailure()),
        syncWallet:
            (
              key, {
              bool discover = false,
              bool allowInitialScan = true,
              SyncReason reason = SyncReason.auto,
            }) async {
              final descriptor = _value(await catalog().find(key));
              _value(
                await synchronize(
                  descriptor,
                  discover: discover,
                  allowInitialScan: allowInitialScan,
                  reason: reason,
                ),
              );
            },
        syncSwapsOutcome: () => SyncOrderSwapsUsecase(swaps()).execute(),
        syncSpOutcome: () async => (await silent().syncWallet()).mapErr(
          (_) => const SyncStorageFailure(),
        ),
        refreshRevisions: () async => _value(await refreshRevisions()),
      ),
    );
  }

  void close() => coordinator.dispose();

  static T _value<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };
}
