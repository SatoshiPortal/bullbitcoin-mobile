import 'package:bb_mobile/core/ark/usecases/check_ark_wallet_setup_usecase.dart';
import 'package:bb_mobile/core/ark/usecases/get_ark_wallet_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/ensure_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_error.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/run_wallet_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockCheckWalletSyncing extends Mock
    implements CheckWalletSyncingUsecase {}

class _MockWatchStarted extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinished extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockWatchElectrum extends Mock
    implements WatchElectrumSyncResultsUsecase {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

class _MockInitTor extends Mock implements InitTorUsecase {}

class _MockIsTorRequired extends Mock implements IsTorRequiredUsecase {}

class _MockGetUnconfirmed extends Mock
    implements GetUnconfirmedIncomingBalanceUsecase {}

class _MockGetAutoSwapSettings extends Mock
    implements GetAutoSwapSettingsUsecase {}

class _MockSaveAutoSwapSettings extends Mock
    implements SaveAutoSwapSettingsUsecase {}

class _MockDisableAutoswapWarning extends Mock
    implements DisableAutoswapWarningUsecase {}

class _MockDisableAutoswap extends Mock implements DisableAutoswapUsecase {}

class _MockAutoSwapExecution extends Mock implements AutoSwapExecutionUsecase {}

class _MockRunWalletAutoSweep extends Mock
    implements RunWalletAutoSweepUsecase {}

class _MockDeleteWallet extends Mock implements DeleteWalletUsecase {}

class _MockGetArkWallet extends Mock implements GetArkWalletUsecase {}

class _MockCheckArkWalletSetup extends Mock
    implements CheckArkWalletSetupUsecase {}

class _MockSeedStoreTypeDatasource extends Mock
    implements SeedStoreTypeDatasource {}

class _MockCheckBackupNeeded extends Mock implements CheckBackupNeededUsecase {}

class _MockEnsureSwapMasterKey extends Mock
    implements EnsureSwapMasterKeyUsecase {}

Wallet _bitcoinWallet() => Wallet(
  origin: 'wallet-100',
  label: 'wallet-100',
  network: Network.bitcoinMainnet,
  isDefault: false,
  masterFingerprint: 'fingerprint',
  xpubFingerprint: 'xpub-fingerprint',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external-desc',
  internalPublicDescriptor: 'internal-desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000),
  autoSweepEnabled: true,
);

void main() {
  late _MockGetWallets getWallets;
  late _MockRunWalletAutoSweep runAutoSweep;
  late _MockEnsureSwapMasterKey ensureSwapMasterKey;

  setUpAll(() => registerFallbackValue(_bitcoinWallet()));

  WalletBloc buildBloc() => WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: _MockCheckWalletSyncing(),
    watchStartedWalletSyncsUsecase: _MockWatchStarted(),
    watchFinishedWalletSyncsUsecase: _MockWatchFinished(),
    watchElectrumSyncResultsUsecase: _MockWatchElectrum(),
    syncCoordinator: _MockSyncCoordinator(),
    initializeTorUsecase: _MockInitTor(),
    checkForTorInitializationOnStartupUsecase: _MockIsTorRequired(),
    getUnconfirmedIncomingBalanceUsecase: _MockGetUnconfirmed(),
    getAutoSwapSettingsUsecase: _MockGetAutoSwapSettings(),
    saveAutoSwapSettingsUsecase: _MockSaveAutoSwapSettings(),
    disableAutoswapWarningUsecase: _MockDisableAutoswapWarning(),
    disableAutoswapUsecase: _MockDisableAutoswap(),
    autoSwapExecutionUsecase: _MockAutoSwapExecution(),
    runWalletAutoSweepUsecase: runAutoSweep,
    deleteWalletUsecase: _MockDeleteWallet(),
    getArkWalletUsecase: _MockGetArkWallet(),
    checkArkWalletSetupUsecase: _MockCheckArkWalletSetup(),
    seedStoreTypeDatasource: _MockSeedStoreTypeDatasource(),
    checkBackupNeededUsecase: _MockCheckBackupNeeded(),
    ensureSwapMasterKeyUsecase: ensureSwapMasterKey,
  );

  setUp(() {
    getWallets = _MockGetWallets();
    runAutoSweep = _MockRunWalletAutoSweep();
    ensureSwapMasterKey = _MockEnsureSwapMasterKey();
    // Empty wallet list keeps the handler off the unconfirmed-balance path;
    // _runAutoSweep still runs for the finished wallet.
    when(() => getWallets.execute()).thenAnswer((_) async => []);
    when(() => ensureSwapMasterKey.execute()).thenAnswer((_) async {});
  });

  Future<WalletBloc> syncFinishedWith(AutosweepResult result) async {
    when(() => runAutoSweep.execute(any())).thenAnswer((_) async => result);
    final bloc = buildBloc();
    bloc.add(WalletSyncFinished(_bitcoinWallet()));
    await pumpEventQueue();
    return bloc;
  }

  test('a failed sweep surfaces a wallet warning', () async {
    final bloc = await syncFinishedWith(
      AutosweepFailed(AutosweepUnexpectedException('broadcast failed')),
    );
    expect(bloc.state.warnings, hasLength(1));
    expect(bloc.state.warnings.single.type, WarningType.error);
    await bloc.close();
  });

  test('a no-default-wallet skip surfaces a wallet warning', () async {
    final bloc = await syncFinishedWith(
      const AutosweepSkipped(AutosweepSkipReason.noDefaultWallet),
    );
    expect(bloc.state.warnings, hasLength(1));
    await bloc.close();
  });

  test('a dust skip stays silent', () async {
    final bloc = await syncFinishedWith(
      const AutosweepSkipped(AutosweepSkipReason.dust),
    );
    expect(bloc.state.warnings, isEmpty);
    await bloc.close();
  });

  test('a successful sweep clears any prior autosweep warning', () async {
    when(() => runAutoSweep.execute(any())).thenAnswer(
      (_) async => AutosweepFailed(AutosweepUnexpectedException('x')),
    );
    final bloc = buildBloc();
    bloc.add(WalletSyncFinished(_bitcoinWallet()));
    await pumpEventQueue();
    expect(bloc.state.warnings, hasLength(1));

    // Next sync sweeps cleanly -> the autosweep warning must disappear.
    when(
      () => runAutoSweep.execute(any()),
    ).thenAnswer((_) async => const AutosweepSwept('txid'));
    bloc.add(WalletSyncFinished(_bitcoinWallet()));
    await pumpEventQueue();
    expect(bloc.state.warnings, isEmpty);
    await bloc.close();
  });

  test('the sweep warning does not clobber the electrum warning', () async {
    when(() => runAutoSweep.execute(any())).thenAnswer(
      (_) async => AutosweepFailed(AutosweepUnexpectedException('x')),
    );
    final bloc = buildBloc();

    // An electrum-server failure warning is already present.
    bloc.add(
      const ElectrumSyncResultChanged(
        ElectrumSyncResult(isLiquid: false, success: false),
      ),
    );
    await pumpEventQueue();
    expect(bloc.state.warnings, hasLength(1));

    // A failed sweep adds its warning additively, keeping the electrum one.
    bloc.add(WalletSyncFinished(_bitcoinWallet()));
    await pumpEventQueue();
    expect(bloc.state.warnings, hasLength(2));
    await bloc.close();
  });
}
