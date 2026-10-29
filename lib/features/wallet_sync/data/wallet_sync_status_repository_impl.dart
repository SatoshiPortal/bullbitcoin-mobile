import 'dart:async';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../domain/repositories/wallet_sync_status_repository.dart';
import '../domain/wallet_sync_options_failure.dart';
import '../domain/wallet_sync_status.dart';

class WalletSyncStatusRepositoryImpl implements WalletSyncStatusRepository {
  final WalletMetadataDatasource _wallets;
  final SettingsRepository _settings;
  final WalletTransactionSyncFacade _sync;
  final WalletSyncMetadataPort _metadata;
  final _preferenceTimers = <Timer>{};
  bool _disposed = false;
  final _lastFailures = <String, WalletSyncOptionsFailure>{};
  final _changes = StreamController<String>.broadcast();
  final _failures =
      StreamController<
        ({String id, WalletSyncOptionsFailure failure})
      >.broadcast();

  WalletSyncStatusRepositoryImpl({
    required this._wallets,
    required this._settings,
    required this._sync,
    required this._metadata,
  });

  @override
  void invalidate(String walletId) {
    _lastFailures.remove(walletId);
    _changes.add(walletId);
  }

  @override
  void reportFailure(String walletId, WalletSyncOptionsFailure failure) {
    _lastFailures[walletId] = failure;
    _failures.add((id: walletId, failure: failure));
  }

  @override
  Stream<WalletSyncStatus> watch(String walletId) => Stream.multi((controller) {
    if (_disposed) {
      controller.close();
      return;
    }
    var cancelled = false;
    var generation = 0;
    WalletNetworkKey? observedKey;
    WalletSyncStatus? current;
    final engineSubscriptions = <StreamSubscription<Object?>>[];
    void emit(WalletSyncStatus status) {
      if (cancelled || _disposed) return;
      current = status;
      controller.add(status);
    }

    Future<void> reload() async {
      final run = ++generation;
      final previousSubscriptions = List.of(engineSubscriptions);
      engineSubscriptions.clear();
      for (final subscription in previousSubscriptions) {
        await subscription.cancel();
      }
      try {
        final wallet = await _wallets.fetch(walletId);
        if (wallet == null) throw const FormatException('Wallet unavailable');
        final settings = await _settings.fetch();
        final key = WalletNetworkKey(
          walletId,
          wallet.isBitcoin ? 'bitcoin' : 'liquid',
          wallet.isTestnet ? 'testnet' : 'mainnet',
        );
        observedKey = key;
        final checkpointResult = const ResolveBitcoinSyncCheckpointUsecase()
            .execute(
              network: wallet.isTestnet
                  ? BitcoinNetwork.testnet
                  : BitcoinNetwork.mainnet,
              birthday: wallet.birthday,
              scriptType: BitcoinSyncScriptType.fromDescriptor(
                wallet.externalPublicDescriptor,
              ),
              now: DateTime.now().toUtc(),
            );
        if (checkpointResult case Err()) {
          throw const FormatException('Checkpoint unavailable');
        }
        final checkpoint =
            (checkpointResult
                    as Ok<BitcoinSyncCheckpoint, WalletTransactionSyncFailure>)
                .value;
        final policy = BdkCbfConfiguration(
          externalPublicDescriptor: wallet.externalPublicDescriptor,
          internalPublicDescriptor: wallet.internalPublicDescriptor,
          isTestnet: wallet.isTestnet,
          databaseFilePath: '',
          checkpoint: checkpoint,
        ).scanPolicyFingerprint;
        final metadata = _metadata;
        final private =
            wallet.isBitcoin &&
            wallet.bitcoinSyncSource == BitcoinSyncSource.compactBlockFilters;
        final complete =
            !private ||
            metadata is WalletCbfMetadataPort &&
                await (metadata as WalletCbfMetadataPort)
                    .isCbfDiscoveryComplete(key, policy);
        final lastSuccess = await _metadata.readLastSuccessfulSyncAt(key);
        if (cancelled || run != generation) return;
        emit(
          WalletSyncStatus(
            source: wallet.bitcoinSyncSource,
            recoveryRequired: !complete,
            scanDate: checkpoint.timestamp,
            lastSuccessfulSync: lastSuccess,
            torEnabled: settings.useTorProxy,
            failure: _lastFailures[walletId],
          ),
        );
        Future<void> checkEmpty(int? operationId) async {
          final page = await _sync.listLocal(
            ListLocalTransactionsRequest(key, pageSize: 1),
          );
          if (page case Ok(:final value) when !cancelled && run == generation) {
            final latest = current;
            if (latest != null &&
                latest.progress?.operationId == operationId &&
                latest.progress?.phase == BitcoinSyncPhase.done) {
              emit(latest.copyWith(emptyRecovery: value.items.isEmpty));
            }
          }
        }

        var rate = RecoveryRate();
        int? operationId;
        engineSubscriptions.add(
          _sync.watchBitcoinSyncProgress(key).listen((progress) {
            final status = current;
            if (status == null ||
                !status.isPrivate ||
                cancelled ||
                run != generation ||
                progress.policyFingerprint != policy) {
              return;
            }
            if (progress.operationId != operationId) {
              rate = RecoveryRate();
              operationId = progress.operationId;
            }
            final failure = progress.failure;
            final now = DateTime.now().toUtc();
            final fraction = progress.fraction;
            final unchanged = fraction == status.progress?.fraction;
            final minutes =
                progress.phase == BitcoinSyncPhase.checkingBlocks &&
                    fraction != null
                ? (unchanged ? status.etaMinutes : rate.observe(fraction, now))
                : null;
            emit(
              status.copyWith(
                progress: progress,
                recoveryRequired: progress.phase == BitcoinSyncPhase.done
                    ? false
                    : status.recoveryRequired || progress.isRecovery,
                failure: failure == null ? null : _mapFailure(failure),
                clearFailure: failure == null,
                etaMinutes: minutes,
                rateObservedAt: minutes == null
                    ? null
                    : unchanged
                    ? status.rateObservedAt
                    : now,
              ),
            );
            if (progress.phase == BitcoinSyncPhase.done) {
              unawaited(checkEmpty(progress.operationId));
            }
          }),
        );
        engineSubscriptions.add(
          _sync.watchWalletState(key).listen((state) async {
            final status = current;
            if (status == null || cancelled || run != generation) return;
            if (state is WalletStateFailed && status.isPrivate) {
              emit(
                status.copyWith(
                  failure: _mapFailure(state.failure),
                  lastSuccessfulSync: state.freshness,
                ),
              );
            }
            if (state is WalletStateReady && state.freshness != null) {
              emit(status.copyWith(lastSuccessfulSync: state.freshness));
              if (status.progress case BitcoinSyncProgress(
                phase: BitcoinSyncPhase.done,
              )) {
                await checkEmpty(status.progress?.operationId);
              }
            }
          }),
        );
      } on Exception {
        if (!cancelled && run == generation) {
          emit(
            const WalletSyncStatus(failure: WalletSyncOptionsStorageFailure()),
          );
        }
      }
    }

    var refreshingPreferences = false;
    final preferencesTimer = Timer.periodic(const Duration(minutes: 1), (
      _,
    ) async {
      final key = observedKey;
      if (cancelled || _disposed || key == null || refreshingPreferences) {
        return;
      }
      final run = generation;
      refreshingPreferences = true;
      try {
        final settings = await _settings.fetch();
        final success = await _metadata.readLastSuccessfulSyncAt(key);
        final latest = current;
        if (!cancelled &&
            run == generation &&
            latest != null &&
            (latest.torEnabled != settings.useTorProxy ||
                latest.lastSuccessfulSync != success)) {
          emit(
            latest.copyWith(
              torEnabled: settings.useTorProxy,
              lastSuccessfulSync: success,
              etaMinutes: latest.etaMinutes,
              rateObservedAt: latest.rateObservedAt,
            ),
          );
        }
      } on Exception {
        /* Keep the last observed local preferences until a successful read. */
      } finally {
        refreshingPreferences = false;
      }
    });
    _preferenceTimers.add(preferencesTimer);
    final changes = _changes.stream
        .where((id) => id == walletId)
        .listen((_) => unawaited(reload()));
    final failures = _failures.stream
        .where((event) => event.id == walletId)
        .listen(
          (event) => emit(
            (current ?? const WalletSyncStatus()).copyWith(
              failure: event.failure,
            ),
          ),
        );
    unawaited(reload());
    controller.onCancel = () async {
      cancelled = true;
      preferencesTimer.cancel();
      _preferenceTimers.remove(preferencesTimer);
      generation++;
      await changes.cancel();
      await failures.cancel();
      for (final subscription in engineSubscriptions) {
        await subscription.cancel();
      }
    };
  });

  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _preferenceTimers) {
      timer.cancel();
    }
    _preferenceTimers.clear();
    await _changes.close();
    await _failures.close();
  }
}

WalletSyncOptionsFailure _mapFailure(WalletTransactionSyncFailure failure) =>
    switch (failure) {
      CbfNoPeersFailure() => const WalletSyncNoPeersFailure(),
      CbfTorUnavailableFailure() => const WalletSyncTorFailure(),
      WalletSyncDeferredFailure() ||
      CbfNodeDidNotStopFailure() => const WalletSyncPausedFailure(),
      _ => const WalletSyncUnexpectedFailure(),
    };
