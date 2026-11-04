import 'bdk_electrum_source.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import 'bdk_electrum_cache.dart';
import 'bdk_wallet_transaction_mapper.dart';
import 'bdk_wallet_session.dart';

final class BdkWalletTransactionSource implements WalletTransactionSourcePort {
  final Map<WalletNetworkKey, BdkElectrumConfiguration> _configurations = {};

  /// Receives one line per scan and per failed server, without identifiers.
  final WalletCoordinationLogSink? _logSink;

  final bool _initializeLocal;

  BdkWalletTransactionSource({this._logSink, this._initializeLocal = false});

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
    if (!_initializeLocal && !await file.exists()) {
      return const Err(WalletSourceStateMissingFailure());
    }
    try {
      final open = await BdkWalletSession.open(
        configuration,
        file,
        create: _initializeLocal,
      );
      try {
        return Ok(
          mapBdkObservation(
            open.wallet,
            registration: registration,
            networkOperation: false,
            discover: false,
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
    final configuration = _configuration(registration);
    _configurations[registration.key] = configuration;
    final file = File(configuration.databaseFilePath);
    await file.parent.create(recursive: true);
    final stopwatch = Stopwatch()..start();
    try {
      final open = await BdkWalletSession.open(
        configuration,
        file,
        create: true,
      );
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
          isTestnet: configuration.isTestnet,
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
            update = fetchBdkElectrumUpdate(
              wallet: wallet,
              client: client,
              fullScan: fullScan,
              stopGap: configuration.stopGap,
              batchSize: configuration.stopGap.clamp(50, 1000),
            );
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
    final provided = registration?.configuration;
    final configuration = provided is BdkElectrumConfiguration
        ? provided
        : _configurations[key];
    if (configuration == null) {
      return const Err(WalletSourceStateMissingFailure());
    }
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
