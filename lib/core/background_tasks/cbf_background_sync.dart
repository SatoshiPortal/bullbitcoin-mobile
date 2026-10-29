import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;
import 'cbf_owner_registry.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

const _cbfBackgroundPort = 'bull.cbf.background.policy';

const _cbfForegroundPort = 'bull.cbf.foreground.active';

final class CbfForegroundPresence {
  CbfOwnerRegistration? _owner;
  Future<void> _changes = Future.value();

  Future<bool> setActive(bool active) {
    final result = _changes.then((_) async {
      if (active) {
        _owner ??= await CbfOwnerRegistration.acquire(
          _cbfForegroundPort,
          // Foreground activity blocks background work until lifecycle stop.
          onStop: () async => false,
        );
        return _owner != null;
      }
      final owner = _owner;
      if (owner == null) return true;
      if (!await owner.release()) return false;
      _owner = null;
      return true;
    });
    _changes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> armNative() async =>
      await _owner?.armNative(
        nativeTerminationBoundAfterOwnerExit:
            BdkCbfConfiguration.nativeTerminationBoundAfterOwnerExit,
      ) ??
      false;

  Future<bool> trackNativeNode(SendPort monitor) async =>
      await _owner?.trackNativeNode(monitor) ?? false;
  Future<void> nativeStopped() async {
    await _owner?.nativeStopped();
  }

  Future<void> dispose() async {
    await setActive(false);
  }
}

/// Foreground policy/lifecycle invalidation also reaches an active headless node.
Future<bool> stopActiveCbfBackgroundSync() =>
    CbfOwnerRegistration.stop(_cbfBackgroundPort);

typedef CbfBackgroundOutcome =
    Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>;

/// A run-scoped lazy batch. Queue claims and notifications stay per wallet;
/// each job receives its first boundary, even when jobs execute sequentially.
final class CbfBackgroundSync {
  final BitcoinSyncRouting routing;
  final Future<List<WalletMetadataModel>> Function() wallets;
  final DateTime Function() deadline;
  Future<Map<WalletNetworkKey, CbfBackgroundOutcome>>? _batch;
  Map<WalletNetworkKey, CbfBackgroundOutcome>? _results;

  bool hasCachedResult(WalletNetworkKey key) =>
      _results?.containsKey(key) ?? false;

  CbfBackgroundSync({
    required this.routing,
    required this.wallets,
    required this.deadline,
  });

  Future<CbfBackgroundOutcome> synchronize(WalletNetworkKey key) async =>
      (await (_batch ??= _run().then((results) {
        _results = results;
        return results;
      })))[key] ??
      const Err(WalletSyncDeferredFailure());

  Future<Map<WalletNetworkKey, CbfBackgroundOutcome>> _run() async {
    if (IsolateNameServer.lookupPortByName(_cbfForegroundPort) != null) {
      return const {};
    }
    var cancelled = false;
    final owner = await CbfOwnerRegistration.acquire(
      _cbfBackgroundPort,
      onStop: () async {
        cancelled = true;
        routing.facade.setCbfForegroundActive(false);
        return await routing.facade.stopCbfNodes() is Ok;
      },
    );
    if (owner == null) {
      return const {};
    }
    try {
      if (cancelled ||
          IsolateNameServer.lookupPortByName(_cbfForegroundPort) != null) {
        return const {};
      }
      final remaining = deadline().difference(DateTime.now().toUtc());
      if (remaining <= Duration.zero) return const {};
      routing.facade.setCbfNativeOwnerMonitor(owner.trackNativeNode);
      if (!await owner.armNative(
            nativeTerminationBoundAfterOwnerExit:
                BdkCbfConfiguration.nativeTerminationBoundAfterOwnerExit,
          ) ||
          cancelled) {
        return const {};
      }
      return await _collect(() => cancelled).timeout(remaining);
    } on TimeoutException {
      cancelled = true;
      routing.facade.setCbfForegroundActive(false);
      await routing.facade.stopCbfNodes();
      return const {};
    } finally {
      Future<void> release() async {
        await owner.nativeStopped();
        await owner.release();
      }

      final stopped = await routing.facade.stopCbfNodes();
      if (stopped is Ok) {
        await release();
      } else {
        // Keep the addressable barrier alive until a real native join. The
        // foreground must not create a replacement after a failed join.
        unawaited(() async {
          while (await routing.facade.stopCbfNodes() is Err) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          await release();
        }());
      }
    }
  }

  Future<Map<WalletNetworkKey, CbfBackgroundOutcome>> _collect(
    bool Function() cancelled,
  ) async {
    final current = (await wallets())
        .where(
          (wallet) =>
              wallet.isBitcoin &&
              wallet.bitcoinSyncSource == BitcoinSyncSource.compactBlockFilters,
        )
        .toList();
    // Each network may need three bounded one-second native join attempts.
    final networkCount = current
        .map((wallet) => wallet.isTestnet)
        .toSet()
        .length;
    final stopAt = deadline().subtract(Duration(seconds: 3 * networkCount));
    final registrations = <WalletSourceRegistration>[];
    final failures = <WalletNetworkKey, CbfBackgroundOutcome>{};
    for (final wallet in current) {
      try {
        registrations.add(await routing.registration(wallet, deadline: stopAt));
      } on BitcoinSyncOperationException catch (error) {
        failures[WalletNetworkKey(
          wallet.id,
          'bitcoin',
          wallet.isTestnet ? 'testnet' : 'mainnet',
        )] = Err(
          error.failure,
        );
      } on Exception {
        failures[WalletNetworkKey(
          wallet.id,
          'bitcoin',
          wallet.isTestnet ? 'testnet' : 'mainnet',
        )] = const Err(
          WalletSyncDeferredFailure(),
        );
      }
    }
    if (cancelled()) return const {};
    final results = await routing.facade.catchUpCbfWallets(
      registrations,
      deadline: stopAt,
    );
    return {...failures, ...results};
  }
}
