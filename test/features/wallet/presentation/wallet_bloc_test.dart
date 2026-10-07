import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'dart:async';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_legacy_seed_storage_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
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

class _MockCheckLegacySeedStorageUsecase extends Mock
    implements CheckLegacySeedStorageUsecase {}

class _MockCheckBackupNeededUsecase extends Mock
    implements CheckBackupNeededUsecase {
  _MockCheckBackupNeededUsecase() {
    when(execute).thenAnswer((_) async => const Ok(false));
  }
}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockExternalTorStatusUsecase extends Mock
    implements GetExternalTorProxyStatusUsecase {}

class _MockCheckSpWalletSetupForWalletUsecase extends Mock
    implements CheckSpWalletSetupForWalletUsecase {}

class _MockCheckSpScanningForWalletUsecase extends Mock
    implements CheckSpScanningForWalletUsecase {}

class _MockRefreshSpWalletForWalletUsecase extends Mock
    implements RefreshSpWalletForWalletUsecase {}

class _MockWatchSpWalletUsecase extends Mock implements WatchSpWalletUsecase {}

class _MockCheckSpFeatureGateForWalletUsecase extends Mock
    implements CheckSpFeatureGateForWalletUsecase {}

WalletBloc createBloc(GetExternalTorProxyStatusUsecase externalStatus) {
  return WalletBloc(
    getWalletsUsecase: _MockGetWalletsUsecase(),
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: _stubbedSync(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    checkLegacySeedStorageUsecase: _stubbedLegacySeedCheck(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: externalStatus,
    checkSpWalletSetupForWalletUsecase:
        _MockCheckSpWalletSetupForWalletUsecase(),
    checkSpScanningForWalletUsecase: _MockCheckSpScanningForWalletUsecase(),
    refreshSpWalletForWalletUsecase: _MockRefreshSpWalletForWalletUsecase(),
    watchSpWalletUsecase: _MockWatchSpWalletUsecase(),
    checkSpFeatureGateForWalletUsecase:
        _MockCheckSpFeatureGateForWalletUsecase(),
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

  test('a later sync event does not wipe the refresh failure', () async {
    // Each wallet's datasource fires its finished event from a `finally`, so
    // one arrives right after a failed sync. Only start and refresh own the
    // failure; this event must not clear it before the user sees it.
    final bloc = _blocWithFailingSync(const WalletSyncFailure('sync: timeout'));
    addTearDown(bloc.close);

    bloc.add(const WalletRefreshed());
    await pumpEventQueue();
    bloc.add(WalletSyncFinished(_syncedWallet));
    await pumpEventQueue();

    expect(bloc.state.loadFailure, isA<WalletSyncFailure>());
  });

  test(
    'unavailable RecoverBull status still warns about an untested physical backup',
    () async {
      // A first check that cannot read the encrypted-backup status must not
      // leave the badge at its `false` default: a funded wallet whose physical
      // backup was never tested still needs the warning.
      final bloc = _blocWithUnknownRecoverBullStatus(_fundedUnbackedUpWallet);
      addTearDown(bloc.close);

      bloc.add(const WalletStarted());
      await pumpEventQueue();

      expect(bloc.state.totalBalance(), greaterThan(0));
      expect(bloc.state.showBackupWarning(), isTrue);
    },
  );

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
    checkLegacySeedStorageUsecase: _stubbedLegacySeedCheck(),
    checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
    checkSpScanningForWalletUsecase: _stubbedSpScanning(),
    refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
    watchSpWalletUsecase: _stubbedSpWatch(),
    checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
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

CheckLegacySeedStorageUsecase _stubbedLegacySeedCheck() {
  final check = _MockCheckLegacySeedStorageUsecase();
  when(
    check.execute,
  ).thenAnswer((_) async => const Ok<bool, WalletFailure>(false));
  return check;
}

/// Silent Payments stubbed off: with the feature gate closed, the SP refresh
/// settles immediately and the watcher stays silent.
CheckSpFeatureGateForWalletUsecase _stubbedSpGate() {
  final gate = _MockCheckSpFeatureGateForWalletUsecase();
  when(gate.execute).thenAnswer((_) async => false);
  return gate;
}

CheckSpWalletSetupForWalletUsecase _stubbedSpSetup() {
  final setup = _MockCheckSpWalletSetupForWalletUsecase();
  when(setup.execute).thenAnswer((_) async => const Ok(false));
  return setup;
}

CheckSpScanningForWalletUsecase _stubbedSpScanning() {
  final scanning = _MockCheckSpScanningForWalletUsecase();
  when(scanning.execute).thenReturn(false);
  return scanning;
}

RefreshSpWalletForWalletUsecase _stubbedSpRefresh() {
  final refresh = _MockRefreshSpWalletForWalletUsecase();
  when(refresh.execute).thenAnswer((_) async => const Ok(null));
  return refresh;
}

WatchSpWalletUsecase _stubbedSpWatch() {
  final watch = _MockWatchSpWalletUsecase();
  when(watch.execute).thenAnswer((_) => const Stream.empty());
  return watch;
}

/// A bloc whose wallet reads succeed but whose sync round fails, so the
/// stale-balance path can be driven.
final _syncedWallet = Wallet(
  origin: 'w1',
  label: 'Test',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: 'abcd1234',
  xpubFingerprint: 'abcd1234',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

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
    checkLegacySeedStorageUsecase: _stubbedLegacySeedCheck(),
    checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
    checkSpScanningForWalletUsecase: _stubbedSpScanning(),
    refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
    watchSpWalletUsecase: _stubbedSpWatch(),
    checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
  );
}

final _fundedUnbackedUpWallet = Wallet(
  origin: 'w2',
  label: 'Funded',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: 'abcd1234',
  xpubFingerprint: 'abcd1234',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(100000),
);

/// A bloc whose wallets load and sync, but whose backup check runs the real
/// use case against a RecoverBull status that could not be read.
WalletBloc _blocWithUnknownRecoverBullStatus(Wallet wallet) {
  final getWallets = _MockGetWalletsUsecase();
  when(
    () => getWallets.execute(
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([wallet]));

  final syncing = _MockCheckWalletSyncingUsecase();
  when(
    () => syncing.execute(walletId: any(named: 'walletId')),
  ).thenReturn(const Ok<bool, WalletFailure>(false));

  registerFallbackValue(Environment.mainnet);
  final walletRepository = _MockWalletRepository();
  when(
    () => walletRepository.getWallets(
      environment: any(named: 'environment'),
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => Ok<List<Wallet>, WalletFailure>([wallet]));
  final settings = _MockSettings();
  when(() => settings.environment).thenReturn(Environment.mainnet);
  final settingsRepository = _MockSettingsRepository();
  when(settingsRepository.fetch).thenAnswer((_) async => settings);

  return WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: syncing,
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: _stubbedSync(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    checkLegacySeedStorageUsecase: _stubbedLegacySeedCheck(),
    checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
    checkSpScanningForWalletUsecase: _stubbedSpScanning(),
    refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
    watchSpWalletUsecase: _stubbedSpWatch(),
    checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
    checkBackupNeededUsecase: CheckBackupNeededUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
      recoverBullStatus: (_) async => const RecoverBullStatus.unavailable(),
    ),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
  );
}
