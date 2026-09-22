import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockCheckWalletSyncingUsecase extends Mock
    implements CheckWalletSyncingUsecase {}

class _MockWatchWalletSyncEventsUsecase extends Mock
    implements WatchWalletSyncEventsUsecase {}

class _MockSyncWalletsUsecase extends Mock implements SyncWalletsUsecase {}

class _MockGetUnconfirmedIncomingBalanceUsecase extends Mock
    implements GetUnconfirmedIncomingBalanceUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockCheckBackupNeededUsecase extends Mock
    implements CheckBackupNeededUsecase {}

class _MockExternalTorStatusUsecase extends Mock
    implements GetExternalTorProxyStatusUsecase {}

WalletBloc createBloc(GetExternalTorProxyStatusUsecase externalStatus) {
  return WalletBloc(
    getWalletsUsecase: _MockGetWalletsUsecase(),
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: _stubbedSync(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    seedRepository: _stubbedSeedRepository(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: externalStatus,
  );
}

void main() {
  for (final scenario in [
    (
      'unavailable Bitcoin proxy points to Tor settings',
      ExternalTorProxyStatus.unavailable,
      WalletWarningAction.torSettings,
    ),
    (
      'available Bitcoin proxy keeps Electrum settings',
      ExternalTorProxyStatus.available,
      WalletWarningAction.electrumSettings,
    ),
    (
      'disabled Bitcoin proxy keeps Electrum settings',
      ExternalTorProxyStatus.disabled,
      WalletWarningAction.electrumSettings,
    ),
  ]) {
    test(scenario.$1, () async {
      final status = _MockExternalTorStatusUsecase();
      when(status.execute).thenAnswer((_) async => scenario.$2);
      final bloc = createBloc(status);
      addTearDown(bloc.close);

      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: false, success: false),
        ),
      );
      final state = await bloc.stream.firstWhere(
        (state) => state.warnings.isNotEmpty,
      );

      expect(state.warnings.single.action, scenario.$3);
    });
  }

  test(
    'Liquid-only failure keeps Electrum settings without checking SOCKS',
    () async {
      final status = _MockExternalTorStatusUsecase();
      final bloc = createBloc(status);
      addTearDown(bloc.close);

      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: true, success: false),
        ),
      );
      final state = await bloc.stream.firstWhere(
        (state) => state.warnings.isNotEmpty,
      );

      expect(
        state.warnings.single.action,
        WalletWarningAction.electrumSettings,
      );
      verifyNever(status.execute);
    },
  );

  test(
    'a newer success clears a warning after an older proxy check completes',
    () async {
      final status = _MockExternalTorStatusUsecase();
      final started = Completer<void>();
      final release = Completer<ExternalTorProxyStatus>();
      when(status.execute).thenAnswer((_) async {
        started.complete();
        return release.future;
      });
      final bloc = createBloc(status);
      addTearDown(bloc.close);

      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: false, success: false),
        ),
      );
      await started.future;
      final observed = <WalletState>[];
      final subscription = bloc.stream.listen(observed.add);
      final recentDecision = Completer<void>();
      final decisionSubscription = bloc.stream.listen((state) {
        if (state.warnings.isEmpty && !recentDecision.isCompleted) {
          recentDecision.complete();
        }
      });
      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: false, success: true),
        ),
      );
      await Future.any<void>([
        recentDecision.future,
        Future<void>.delayed(const Duration(milliseconds: 100)),
      ]);
      expect(recentDecision.isCompleted, isTrue);
      release.complete(ExternalTorProxyStatus.unavailable);

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await decisionSubscription.cancel();
      expect(observed.every((state) => state.warnings.isEmpty), isTrue);
      expect(bloc.state.warnings, isEmpty);
    },
  );

  test(
    'a failed wallet load is reported, not shown as an empty wallet',
    () async {
      // Before #1895 this state was invisible: WalletStatus.failure was never
      // read by the UI, so a failed load rendered a 0-sat home screen that reads
      // as "you have no wallets" rather than as an error.
      final bloc = _blocWithFailingLoad(
        const WalletStorageFailure('getWallets failed: SqliteException'),
      );
      addTearDown(bloc.close);

      bloc.add(const WalletStarted());
      await pumpEventQueue();

      expect(bloc.state.status, WalletStatus.failure);
      expect(bloc.state.loadFailure, isA<WalletStorageFailure>());
    },
  );

  test('a failed sync round is reported, not silently dropped', () async {
    // The wallets themselves load, so the list stays correct — but a refresh
    // that silently did nothing reads as a frozen screen. This also makes the
    // sync-specific card reachable: without it, WalletSyncFailure never
    // reached state.failure and the card was dead code.
    final bloc = _blocWithFailingSync(const WalletSyncFailure('sync: timeout'));
    addTearDown(bloc.close);

    bloc.add(const WalletRefreshed());
    await pumpEventQueue();

    expect(bloc.state.status, WalletStatus.success);
    expect(bloc.state.loadFailure, isA<WalletSyncFailure>());
  });

  test('"no wallets yet" routes to onboarding instead of reporting', () async {
    // Not an error condition: the router redirects, so nothing is rendered.
    final bloc = _blocWithFailingLoad(const NoWalletsFoundFailure());
    addTearDown(bloc.close);

    bloc.add(const WalletStarted());
    await pumpEventQueue();

    expect(bloc.state.noWalletsFound, isTrue);
    expect(bloc.state.loadFailure, isNull);
  });
}

/// Builds a bloc whose wallet load fails, so the failure path can be driven.
WalletBloc _blocWithFailingLoad(WalletFailure failure) {
  final getWallets = _MockGetWalletsUsecase();
  when(
    () => getWallets.execute(
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => Err<List<Wallet>, WalletFailure>(failure));

  return WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: _stubbedSync(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    seedRepository: _stubbedSeedRepository(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
  );
}

/// The three watchers, stubbed to stay silent. Every test that cares about
/// sync events drives the bloc directly instead.
WatchWalletSyncEventsUsecase _stubbedWatchers() {
  final watchers = _MockWatchWalletSyncEventsUsecase();
  when(watchers.started).thenAnswer((_) => const Stream.empty());
  when(watchers.finished).thenAnswer((_) => const Stream.empty());
  when(watchers.electrumResults).thenAnswer((_) => const Stream.empty());
  return watchers;
}

SyncWalletsUsecase _stubbedSync() {
  // mocktail needs a concrete SyncTrigger to match  against.
  registerFallbackValue(SyncTrigger.automatic);
  final sync = _MockSyncWalletsUsecase();
  when(
    () => sync.execute(trigger: any(named: 'trigger')),
  ).thenAnswer((_) async => const Ok<void, WalletFailure>(null));
  return sync;
}

SeedRepository _stubbedSeedRepository() {
  final repo = _MockSeedRepository();
  when(
    repo.isOnLegacyStorage,
  ).thenAnswer((_) async => const Ok<bool, SeedFailure>(false));
  return repo;
}

/// A bloc whose wallet reads succeed but whose sync round fails, so the
/// stale-balance path can be driven.
WalletBloc _blocWithFailingSync(WalletFailure failure) {
  final getWallets = _MockGetWalletsUsecase();
  when(
    () => getWallets.execute(
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => const Ok<List<Wallet>, WalletFailure>([]));

  registerFallbackValue(SyncTrigger.automatic);
  final sync = _MockSyncWalletsUsecase();
  when(
    () => sync.execute(trigger: any(named: 'trigger')),
  ).thenAnswer((_) async => Err<void, WalletFailure>(failure));

  final syncing = _MockCheckWalletSyncingUsecase();
  when(
    () => syncing.execute(walletId: any(named: 'walletId')),
  ).thenReturn(const Ok<bool, WalletFailure>(false));

  return WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: syncing,
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: sync,
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    seedRepository: _stubbedSeedRepository(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
  );
}
