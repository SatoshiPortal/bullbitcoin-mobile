import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockCheckWalletSyncingUsecase extends Mock
    implements CheckWalletSyncingUsecase {}

class _MockWatchStartedWalletSyncsUsecase extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockWatchElectrumSyncResultsUsecase extends Mock
    implements WatchElectrumSyncResultsUsecase {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

class _MockGetUnconfirmedIncomingBalanceUsecase extends Mock
    implements GetUnconfirmedIncomingBalanceUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockSeedStoreTypeDatasource extends Mock
    implements SeedStoreTypeDatasource {}

class _MockCheckBackupNeededUsecase extends Mock
    implements CheckBackupNeededUsecase {}

class _MockExternalTorStatusUsecase extends Mock
    implements GetExternalTorProxyStatusUsecase {}

WalletBloc createBloc(GetExternalTorProxyStatusUsecase externalStatus) {
  return WalletBloc(
    getWalletsUsecase: _MockGetWalletsUsecase(),
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchStartedWalletSyncsUsecase: _MockWatchStartedWalletSyncsUsecase(),
    watchFinishedWalletSyncsUsecase: _MockWatchFinishedWalletSyncsUsecase(),
    watchElectrumSyncResultsUsecase: _MockWatchElectrumSyncResultsUsecase(),
    syncCoordinator: _MockSyncCoordinator(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    seedStoreTypeDatasource: _MockSeedStoreTypeDatasource(),
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
}
