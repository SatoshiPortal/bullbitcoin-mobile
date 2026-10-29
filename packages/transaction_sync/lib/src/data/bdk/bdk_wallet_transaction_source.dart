import 'bdk_cbf_node.dart';
import 'bdk_cbf_service.dart';
import 'cbf_recovery_files.dart';
import '../../domain/entities/bitcoin_sync_progress.dart';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../domain/ports/wallet_transaction_source_port.dart';
import '../../domain/entities/wallet_source_sync_observation.dart';
import '../../domain/entities/wallet_source_observation.dart';
import '../../domain/wallet_source_configuration.dart';
import '../../domain/wallet_network_key.dart';
import '../../domain/wallet_source_registration.dart';
import '../../domain/wallet_transaction_sync_failure.dart';
import '../../durable_wallet_source_operation_coordinator.dart'
    show
        WalletCoordinationLogEvent,
        WalletCoordinationLogLevel,
        WalletCoordinationLogSink;
import '../../wallet_source_session.dart';
import 'bdk_electrum_cache.dart';
import 'bdk_wallet_transaction_mapper.dart';

final class BdkWalletTransactionSource
    implements WalletTransactionSourcePort, BitcoinSyncProgressRepository {
  final Map<WalletNetworkKey, BdkElectrumConfiguration> _configurations = {};

  /// Receives one line per scan and per failed server, without identifiers.
  final WalletCoordinationLogSink? _logSink;

  BdkCbfService? reactive;
  final BdkCbfReactiveNodeFactory cbfNodeFactory;

  BdkWalletTransactionSource({
    this._logSink,
    this.cbfNodeFactory = NativeBdkCbfReactiveNode.create,
  });

  void rememberRegistration(WalletSourceRegistration registration) {
    final configuration = registration.configuration;
    if (configuration is BdkElectrumConfiguration) {
      _configurations[registration.key] = configuration;
    }
  }

  @override
  Stream<BitcoinSyncProgress> watchBitcoinSyncProgress(WalletNetworkKey key) =>
      reactive?.watchBitcoinSyncProgress(key) ?? const Stream.empty();

  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  refreshLocal(
    WalletSourceRegistration registration,
    WalletSourceSession session,
  ) async {
    session.ensureOpen();
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    final file = File(configuration.databaseFilePath);
    if (!await file.exists()) {
      return const Err(WalletSourceStateMissingFailure());
    }
    try {
      final open = await _open(
        registration,
        configuration,
        file,
        create: false,
      );
      try {
        final unrelayed =
            await reactive?.notBroadcastTxids(open.wallet, registration) ??
            const <String>{};
        return Ok(
          mapBdkObservation(
            open.wallet,
            registration: registration,
            networkOperation: false,
            discover: false,
            compactBlockFilters: configuration is BdkCbfConfiguration,
            complete:
                configuration is! BdkCbfConfiguration ||
                await reactive?.metadata.isCbfDiscoveryComplete(
                      registration.key,
                      configuration.scanPolicyFingerprint,
                    ) ==
                    true,
            notBroadcastTxids: configuration is BdkCbfConfiguration
                ? unrelayed
                : const <String>{},
          ),
        );
      } finally {
        open.dispose();
      }
    } catch (error) {
      return Err(_loadFailure(file, error));
    }
  }

  @override
  Future<Result<WalletSourceSyncObservation, WalletTransactionSyncFailure>>
  synchronize(
    WalletSourceRegistration registration,
    WalletSourceSession session, {
    required bool discover,
    bool allowInitialScan = true,
  }) async {
    session.ensureOpen();
    if (registration.configuration
        case final BdkCbfConfiguration configuration) {
      _configurations[registration.key] = configuration;
      // A caller holding this session must return before the service can
      // acquire short update sessions. CBF network work enters via the facade.
      return const Err(WalletSyncDeferredFailure());
    }
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    final file = File(configuration.databaseFilePath);
    await file.parent.create(recursive: true);
    final stopwatch = Stopwatch()..start();
    try {
      final open = await _open(registration, configuration, file, create: true);
      final wallet = open.wallet;
      final cache = BdkElectrumCache.open(configuration.databaseFilePath);
      bdk.ElectrumClient? syncedClient;
      try {
        // A wallet that never synced has revealed nothing yet: only a full
        // scan finds its history, like the app's first sync.
        final firstSync = wallet.latestCheckpoint().height <= 0;
        if (firstSync && !discover && !allowInitialScan) {
          return const Err(InitialScanRequiredFailure());
        }
        final fullScan = discover || firstSync;
        final reason = discover
            ? 'discovery'
            : firstSync
            ? 'first_sync'
            : 'routine';
        BdkElectrumCachePrefill? prefill;
        var attempt = 0;
        final baselineTxids = mapBdkTransactions(
          wallet,
        ).map((transaction) => transaction.txid).toSet();
        // Connection phase: only connection/server errors may fall through
        // to the next URL. Nothing has been applied to the wallet yet.
        bdk.Update? update;
        for (final url in configuration.electrumUrls) {
          attempt++;
          bdk.ElectrumClient? client;
          try {
            // The constructor itself opens the connection; it must sit
            // inside the per-URL try so a refused server falls through to
            // the next one instead of aborting the whole operation.
            client = bdk.ElectrumClient(
              url: url,
              socks5: configuration.socks5,
              timeout: configuration.timeout,
              retry: configuration.retry,
              validateDomain: configuration.validateDomain,
            );
            prefill = cache?.prefill(client, wallet);
            if (fullScan) {
              final requestBuilder = wallet.startFullScan();
              try {
                final request = requestBuilder.build();
                try {
                  update = client.fullScan(
                    request: request,
                    stopGap: configuration.stopGap,
                    batchSize: configuration.stopGap.clamp(50, 1000),
                    fetchPrevTxouts: true,
                  );
                } finally {
                  request.dispose();
                }
              } finally {
                requestBuilder.dispose();
              }
            } else {
              final requestBuilder = wallet.startSyncWithRevealedSpks();
              try {
                final request = requestBuilder.build();
                try {
                  update = client.sync_(
                    request: request,
                    batchSize: configuration.stopGap.clamp(50, 1000),
                    fetchPrevTxouts: true,
                  );
                } finally {
                  request.dispose();
                }
              } finally {
                requestBuilder.dispose();
              }
            }
            // Kept open: its cache holds the parents to remember below.
            syncedClient = client;
            client = null;
            break;
          } catch (error) {
            // Connection-level failure: try the next configured server.
            _log(
              WalletCoordinationLogLevel.warning,
              'BDK source server failed attempt=$attempt/'
              '${configuration.electrumUrls.length} '
              'error=${error.runtimeType} elapsed_ms=${stopwatch.elapsedMilliseconds}',
            );
          } finally {
            client?.dispose();
          }
        }
        if (update == null) {
          _log(
            WalletCoordinationLogLevel.warning,
            'BDK source unavailable servers=${configuration.electrumUrls.length} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
          );
          return const Err(SourceFailure(SourceFailureReason.unavailable));
        }

        // Fatal phase: apply/persist/mapping errors must surface, never be
        // retried against another server or reported as unavailability.
        try {
          try {
            wallet.applyUpdate(update: update);
            // `Wallet.persist` returns whether staged changes were written
            // (false simply means nothing was staged); persistence FAILURES
            // throw.
            wallet.persist(persister: open.persister);
          } catch (error) {
            // Local storage refused the update; nothing is wrong with the
            // source, so a later attempt can succeed.
            _log(
              WalletCoordinationLogLevel.warning,
              'BDK source storage failed error=${error.runtimeType}',
            );
            return const Err(SourceStorageFailure());
          }
          final remembered = syncedClient == null
              ? null
              : cache?.rememberParents(syncedClient, wallet);
          _log(
            WalletCoordinationLogLevel.fine,
            'BDK source sync mode=${fullScan ? 'full_scan' : 'revealed'} '
            'reason=$reason server_attempt=$attempt '
            '${BdkElectrumCache.describe(opened: cache != null, rebuilt: cache?.rebuilt ?? false, prefill: prefill, parents: remembered)} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
          );
          return Ok(
            WalletSourceSyncObservation(
              observation: mapBdkObservation(
                wallet,
                registration: registration,
                networkOperation: true,
                discover: fullScan,
              ),
              baselineTxids: baselineTxids,
            ),
          );
        } catch (error) {
          _log(
            WalletCoordinationLogLevel.warning,
            'BDK source mapping failed error=${error.runtimeType}',
          );
          return const Err(
            ExtractionFailure(safeMessage: 'mapping the source state failed'),
          );
        } finally {
          update.dispose();
        }
      } finally {
        syncedClient?.dispose();
        cache?.close();
        open.dispose();
      }
    } catch (error) {
      _log(
        WalletCoordinationLogLevel.warning,
        'BDK source load failed error=${error.runtimeType}',
      );
      return Err(_loadFailure(file, error));
    }
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
    WalletSourceSession session, {
    WalletSourceRegistration? registration,
  }) async {
    session.ensureOpen();
    final stopped = await reactive?.stop();
    if (stopped case Err(:final failure)) return Err(failure);
    final provided = registration?.configuration;
    final configuration = provided is BdkElectrumConfiguration
        ? provided
        : _configurations[key];
    if (configuration == null) {
      return const Err(WalletSourceStateMissingFailure());
    }
    await deleteCbfRecoveryFiles(configuration.databaseFilePath);
    BdkElectrumCache.delete(configuration.databaseFilePath);
    final file = File(configuration.databaseFilePath);
    if (!await file.exists()) return const Ok(null);
    try {
      await file.delete();
      return const Ok(null);
    } catch (_) {
      return const Err(DeletionFailure());
    }
  }

  BdkElectrumConfiguration _configuration(
    WalletSourceRegistration registration,
  ) {
    final configuration = registration.configuration;
    if (configuration is! BdkElectrumConfiguration) {
      throw StateError('BDK source requires BdkElectrumConfiguration');
    }
    return configuration;
  }

  Future<_OpenWallet> _open(
    WalletSourceRegistration registration,
    BdkElectrumConfiguration configuration,
    File file, {
    required bool create,
  }) async {
    final existed = await file.exists();
    // The persister must outlive the wallet: the uniffi Wallet object keeps
    // using it, so both handles are owned and released together.
    final persister = bdk.Persister.newSqlite(path: file.path);
    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    try {
      external = bdk.Descriptor(
        descriptor: configuration.externalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      internal = bdk.Descriptor(
        descriptor: configuration.internalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      final wallet = (!create || existed)
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: persister,
              lookahead: configuration.stopGap,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: configuration.isTestnet
                  ? bdk.Network.testnet
                  : bdk.Network.bitcoin,
              persister: persister,
              lookahead: configuration.stopGap,
            );
      return _OpenWallet(wallet, persister);
    } catch (_) {
      persister.dispose();
      rethrow;
    } finally {
      internal?.dispose();
      external?.dispose();
    }
  }

  void _log(WalletCoordinationLogLevel level, String message) {
    try {
      _logSink?.call(WalletCoordinationLogEvent(level, message));
    } catch (_) {
      // Logging never changes a sync result.
    }
  }

  WalletTransactionSyncFailure _loadFailure(File file, Object error) =>
      file.existsSync()
      ? const SourceFailure(SourceFailureReason.unknown)
      : const WalletSourceStateMissingFailure();
}

final class _OpenWallet {
  final bdk.Wallet wallet;
  final bdk.Persister persister;

  _OpenWallet(this.wallet, this.persister);

  void dispose() {
    try {
      wallet.dispose();
    } finally {
      persister.dispose();
    }
  }
}
