// Home follows the wallet facade's published catalog (spec 20.2): a passphrase
// wallet's card is on screen while its private session is loaded and gone the
// moment it is locked, without the bloc deciding visibility for itself.
import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _GetWallets extends Mock implements GetWalletsUsecase {}

class _CheckSyncing extends Mock implements CheckWalletSyncingUsecase {}

class _WatchStarted extends Mock implements WatchStartedWalletSyncsUsecase {}

class _WatchFinished extends Mock implements WatchFinishedWalletSyncsUsecase {}

class _WatchElectrum extends Mock implements WatchElectrumSyncResultsUsecase {}

class _Sync extends Mock implements SyncCoordinator {}

class _InitTor extends Mock implements InitTorUsecase {}

class _IsTorRequired extends Mock implements IsTorRequiredUsecase {}

class _Unconfirmed extends Mock
    implements GetUnconfirmedIncomingBalanceUsecase {}

class _DeleteWallet extends Mock implements DeleteWalletUsecase {}

class _SeedStoreType extends Mock implements SeedStoreTypeDatasource {}

class _CheckBackupNeeded extends Mock implements CheckBackupNeededUsecase {}

class _Facade extends Mock implements WalletFacade {}

Wallet _wallet(String id) => Wallet(
  origin: id,
  network: Network.bitcoinTestnet,
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'tpub-test',
  externalPublicDescriptor: 'wpkh(external)',
  internalPublicDescriptor: 'wpkh(internal)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  late StreamController<List<Wallet>> catalog;
  late _GetWallets getWallets;
  late _Facade facade;

  WalletBloc buildBloc() => WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: _CheckSyncing(),
    watchStartedWalletSyncsUsecase: _WatchStarted(),
    watchFinishedWalletSyncsUsecase: _WatchFinished(),
    watchElectrumSyncResultsUsecase: _WatchElectrum(),
    syncCoordinator: _Sync(),
    initializeTorUsecase: _InitTor(),
    checkForTorInitializationOnStartupUsecase: _IsTorRequired(),
    getUnconfirmedIncomingBalanceUsecase: _Unconfirmed(),
    deleteWalletUsecase: _DeleteWallet(),
    seedStoreTypeDatasource: _SeedStoreType(),
    checkBackupNeededUsecase: _CheckBackupNeeded(),
    walletFacade: facade,
  );

  setUp(() {
    catalog = StreamController<List<Wallet>>();
    getWallets = _GetWallets();
    facade = _Facade();
    when(facade.watchVisibleWalletCatalog).thenAnswer((_) => catalog.stream);
    addTearDown(catalog.close);
  });

  test('shows the published catalog when a wallet is loaded', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    catalog.add([_wallet('default'), _wallet('passphrase')]);
    await bloc.stream.firstWhere(
      (state) => state.status == WalletStatus.success,
    );

    expect(
      bloc.state.wallets.map((wallet) => wallet.id),
      containsAll(['default', 'passphrase']),
    );
    // The published catalog is already filtered, so Home does not read again.
    verifyNever(() => getWallets.execute());
  });

  test(
    'drops the passphrase wallet when the catalog stops publishing it',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      catalog.add([_wallet('default'), _wallet('passphrase')]);
      await bloc.stream.firstWhere((state) => state.wallets.length == 2);

      catalog.add([_wallet('default')]);
      await bloc.stream.firstWhere((state) => state.wallets.length == 1);

      expect(
        bloc.state.wallets.map((wallet) => wallet.id),
        isNot(contains('passphrase')),
      );
    },
  );

  test('an empty catalog still surfaces the no-wallets failure', () async {
    when(
      () => getWallets.execute(),
    ).thenThrow(NoWalletsFoundException('none for this environment'));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    catalog.add(const []);
    await bloc.stream.firstWhere(
      (state) => state.status == WalletStatus.failure,
    );

    expect(bloc.state.noWalletsFoundException, isA<NoWalletsFoundException>());
  });
}
