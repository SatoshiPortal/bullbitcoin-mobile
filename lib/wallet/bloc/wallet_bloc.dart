import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/apps_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_network.dart';
import 'package:bb_mobile/_repository/wallet/internal_wallets.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

WalletBloc createWalletBloc(Wallet wallet) {
  return WalletBloc(
    saveDir: wallet.getWalletStorageString(),
    walletSync: locator<WalletSync>(),
    walletsStorageRepository: locator<WalletsStorageRepository>(),
    walletBalance: locator<WalletBalance>(),
    walletAddress: locator<WalletAddress>(),
    networkRepository: locator<InternalNetworkRepository>(),
    walletsRepository: locator<InternalWalletsRepository>(),
    walletTransactionn: locator<WalletTx>(),
    walletCreatee: locator<WalletCreate>(),
    appWalletsRepository: locator<AppWalletsRepository>(),
    wallet: wallet,
  );
}

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required String saveDir,
    required WalletSync walletSync,
    required WalletsStorageRepository walletsStorageRepository,
    required WalletBalance walletBalance,
    required WalletAddress walletAddress,
    // required NetworkCubit networkCubit,
    // required WatchTxsBloc swapBloc,
    required InternalNetworkRepository networkRepository,
    required InternalWalletsRepository walletsRepository,
    required WalletTx walletTransactionn,
    required WalletCreate walletCreatee,
    bool fromStorage = true,
    required Wallet wallet,
    required AppWalletsRepository appWalletsRepository,
  })  : _fromStorage = fromStorage,
        // _swapBloc = swapBloc,
        // _networkCubit = networkCubit,
        _walletTransactionn = walletTransactionn,
        _walletCreate = walletCreatee,
        _walletAddress = walletAddress,
        _walletBalance = walletBalance,
        _walletSync = walletSync,
        _walletsRepository = walletsRepository,
        _internalNetworkRepository = networkRepository,
        _walletsStorageRepository = walletsStorageRepository,
        _appWalletsRepository = appWalletsRepository,
        super(WalletState(wallet: wallet)) {
    on<LoadWallet>(_loadWallet);
    on<SyncWallet>(_syncWallet, transformer: droppable());
    on<RemoveInternalWallet>(_removeInternalWallet);
    on<KillSync>(_killSync);
    on<UpdateWallet>(_updateWallet, transformer: sequential());
    on<GetBalance>(_getBalance);
    on<ListTransactions>(_listTransactions);
    on<GetFirstAddress>(_getFirstAddress);
    on<WalletSubscribe>((event, emit) async {
      await emit.forEach(
        _appWalletsRepository.walletService(event.walletId),
        onData: (WalletService w) => state.copyWith(
          wallet: w.wallet,
          syncing: w.syncing,
        ),
      );
    });

    add(LoadWallet(saveDir));
  }

  final WalletsStorageRepository _walletsStorageRepository;
  final InternalNetworkRepository _internalNetworkRepository;
  final InternalWalletsRepository _walletsRepository;

  final WalletSync _walletSync;
  final WalletBalance _walletBalance;
  final WalletAddress _walletAddress;
  final WalletCreate _walletCreate;
  final WalletTx _walletTransactionn;

  // final NetworkCubit _networkCubit;
  // final WatchTxsBloc _swapBloc;

  final bool _fromStorage;

  final AppWalletsRepository _appWalletsRepository;

  @override
  Future<void> close() {
    _walletsRepository.removeWallet(
      state.wallet.baseWalletType,
      state.wallet.id,
    );
    return super.close();
  }

  Future<void> _loadWallet(LoadWallet event, Emitter<WalletState> emit) async {
    emit(state.copyWith(loadingWallet: true, errLoadingWallet: ''));

    final walletService =
        _appWalletsRepository.getWalletServiceById(state.wallet.id);

    final err = walletService?.loadWallet();
    if (err != null) {
      emit(
        state.copyWith(
          loadingWallet: false,
          errLoadingWallet: err.toString(),
        ),
      );
      return;
    }

    await walletService?.updateWallet(
      state.wallet,
      saveToStorage: _fromStorage,
      updateTypes: [
        UpdateWalletTypes.load,
      ],
    );

    emit(
      state.copyWith(
        loadingWallet: false,
        name: walletService?.wallet.name ?? '',
      ),
    );

    // final (wallet, err) = await _walletCreate.loadPublicWallet(
    //   saveDir: event.saveDir,
    //   wallet: state.wallet,
    //   network: _networkCubit.state.getBBNetwork(),
    // );
    // if (err != null) {
    //   emit(
    //     state.copyWith(
    //       loadingWallet: false,
    //       errLoadingWallet: err.toString(),
    //     ),
    //   );
    //   return;
    // }

    // emit(
    //   state.copyWith(
    //     loadingWallet: false,
    //     errLoadingWallet: '',
    //     name: wallet!.name ?? '',
    //     loadingAttepmtsLeft: 3,
    //   ),
    // );

    // add(
    //   UpdateWallet(
    //     wallet,
    //     saveToStorage: _fromStorage,
    //     updateTypes: [UpdateWalletTypes.load],
    //   ),
    // );
    await Future.delayed(50.ms);
    add(GetFirstAddress());
    await Future.delayed(200.ms);
    add(SyncWallet());
  }

  FutureOr<void> _removeInternalWallet(
    RemoveInternalWallet event,
    Emitter<WalletState> emit,
  ) {
    _walletsRepository.removeBdkWallet(state.wallet.id ?? '');
  }

  FutureOr<void> _killSync(KillSync event, Emitter<WalletState> emit) {
    _walletSync.cancelSync();
    emit(state.copyWith(syncing: false));
  }

  Future _syncWallet(SyncWallet event, Emitter<WalletState> emit) async {
    if (state.syncing) return;
    // if (state.errLoadingWallet.isNotEmpty && state.loadingAttepmtsLeft > 0) {
    //   emit(state.copyWith(loadingAttepmtsLeft: state.loadingAttepmtsLeft - 1));
    //   add(LoadWallet(state.wallet!.getWalletStorageString()));
    //   return;
    // }
    // // if (walletIsLoaded)
    // // final (wallet, _) = await _walletsStorageRepository.readWallet(
    // //   walletHashId: state.wallet!.id,
    // // );
    // // if (wallet != null)
    // //   emit(
    // //     state.copyWith(
    // //       wallet: wallet,
    // //     ),
    // //   );

    emit(
      state.copyWith(
        // syncing: true,
        errSyncing: '',
      ),
    );

    final err = await _appWalletsRepository
        .getWalletServiceById(state.wallet.id)
        ?.syncWallet();
    if (err != null) {
      emit(
        state.copyWith(
          // syncing: false,
          errSyncing: err.toString(),
        ),
      );
      return;
    }

    // final errNetwork = _internalNetworkRepository.checkNetworks();
    // if (errNetwork != null) {
    //   await _networkCubit.loadNetworks();
    //   await Future.delayed(const Duration(milliseconds: 300));
    //   final errNetwork2 = _internalNetworkRepository.checkNetworks();
    //   if (errNetwork2 != null) {
    //     emit(state.copyWith(syncing: false));
    //     return;
    //   }
    // }

    // await Future.delayed(100.ms);
    // final isLiq = state.isLiq() ? 'Instant' : 'Secure';
    // locator<Logger>().log(
    //   'Start $isLiq  Wallet Sync for ${state.wallet?.id ?? ''}',
    //   printToConsole: true,
    // );
    // final err = await _walletSync.syncWallet(state.wallet!);
    // locator<Logger>().log(
    //   'End $isLiq Wallet Sync for ${state.wallet?.id ?? ''}',
    //   printToConsole: true,
    // );
    // emit(
    //   state.copyWith(
    //     errSyncing: err.toString(),
    //     syncing: false,
    //   ),
    // );
    // if (err != null) {
    //   if (err.message.toLowerCase().contains('panic') &&
    //       state.syncErrCount < 5) {
    //     await _networkCubit.loadNetworks();
    //     await Future.delayed(const Duration(milliseconds: 300));
    //     emit(state.copyWith(syncErrCount: state.syncErrCount + 1));
    //     add(SyncWallet());
    //     return;
    //   }

    //   locator<Logger>().log(err.toString());
    //   return;
    // }

    // emit(state.copyWith(syncing: false, syncErrCount: 0));
    // await Future.delayed(100.ms);

    if (!_fromStorage) add(GetFirstAddress());
    add(GetBalance());

    // emit(state.copyWith(syncing: false));
  }

  Future<void> _getBalance(GetBalance event, Emitter<WalletState> emit) async {
    emit(state.copyWith(loadingBalance: true, errLoadingBalance: ''));

    final err = await _appWalletsRepository
        .getWalletServiceById(state.wallet.id)
        ?.getBalance();
    // final (w, err) = await _walletBalance.getBalance(state.wallet!);
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingBalance: err.toString(),
          loadingBalance: false,
        ),
      );
      return;
    }

    // final (wallet, _) = w!;

    // add(
    //   UpdateWallet(
    //     wallet,
    //     saveToStorage: _fromStorage,
    //     updateTypes: [UpdateWalletTypes.balance],
    //   ),
    // );

    emit(
      state.copyWith(
        loadingBalance: false,
      ),
    );

    add(ListTransactions());
  }

  Future<void> _listTransactions(
    ListTransactions event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(loadingTxs: true, errLoadingWallet: ''));

    // final (wallet, errTxs) =
    //     await _walletTransactionn.getTransactions(state.wallet!);

    final errTxs = await _appWalletsRepository
        .getWalletServiceById(state.wallet.id)
        ?.listTransactions();

    if (errTxs != null) {
      emit(
        state.copyWith(
          errLoadingWallet: errTxs.toString(),
          loadingTxs: false,
        ),
      );
      return;
    }

    // add(
    //   UpdateWallet(
    //     wallet!,
    //     saveToStorage: _fromStorage,
    //     updateTypes: [
    //       UpdateWalletTypes.addresses,
    //       UpdateWalletTypes.transactions,
    //       UpdateWalletTypes.utxos,
    //     ],
    //   ),
    // );
    emit(
      state.copyWith(
        loadingTxs: false,
      ),
    );

    // await Future.delayed(100.ms);

    // _swapBloc.add(WatchWallets(isTestnet: state.wallet!));
  }

  Future<void> _getFirstAddress(
    GetFirstAddress event,
    Emitter<WalletState> emit,
  ) async {
    final (address, err) =
        await _walletAddress.peekIndex(wallet: state.wallet, idx: 0);
    if (err != null) {
      emit(state.copyWith(errSyncingAddresses: err.toString()));
      return;
    }

    emit(
      state.copyWith(
        firstAddress: Address(
          address: address!,
          index: 0,
          kind: AddressKind.deposit,
          state: AddressStatus.unused,
        ),
      ),
    );
  }

  Future<void> _updateWallet(
    UpdateWallet event,
    Emitter<WalletState> emit,
  ) async {
    if (!event.saveToStorage) {
      emit(state.copyWith(wallet: event.wallet));
      return;
    }

    if (event.updateTypes.contains(UpdateWalletTypes.load)) {
      final err = await _walletsStorageRepository.updateWallet(
        event.wallet,
      );
      if (err != null) locator<Logger>().log(err.toString());

      emit(state.copyWith(wallet: event.wallet));
      return;
    }

    final eventWallet = event.wallet;
    var (storageWallet, errr) = await _walletsStorageRepository.readWallet(
      walletHashId: state.wallet.getWalletStorageString(),
    );
    if (errr != null) locator<Logger>().log(errr.toString());
    if (storageWallet == null) return;

    for (final eventType in event.updateTypes) {
      switch (eventType) {
        case UpdateWalletTypes.load:
          break;
        case UpdateWalletTypes.balance:
          if (eventWallet.balance != null) {
            storageWallet = storageWallet!.copyWith(
              balance: eventWallet.balance,
              fullBalance: eventWallet.fullBalance,
            );
          }
        case UpdateWalletTypes.transactions:
          if (eventWallet.transactions.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              transactions: eventWallet.transactions,
            );
          }

          if (eventWallet.unsignedTxs.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              unsignedTxs: eventWallet.unsignedTxs,
            );
          }

        case UpdateWalletTypes.swaps:
          storageWallet = storageWallet!.copyWith(
            swaps: eventWallet.swaps,
            revKeyIndex: eventWallet.revKeyIndex,
            subKeyIndex: eventWallet.subKeyIndex,
          );

        case UpdateWalletTypes.addresses:
          if (eventWallet.myAddressBook.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              myAddressBook: eventWallet.myAddressBook,
            );
          }

          if (eventWallet.externalAddressBook != null &&
              eventWallet.externalAddressBook!.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              externalAddressBook: eventWallet.externalAddressBook,
            );
          }

          if (eventWallet.lastGeneratedAddress != null) {
            storageWallet = storageWallet!.copyWith(
              lastGeneratedAddress: eventWallet.lastGeneratedAddress,
            );
          }

        case UpdateWalletTypes.utxos:
          storageWallet = storageWallet!.copyWith(utxos: eventWallet.utxos);

        case UpdateWalletTypes.settings:
          if (eventWallet.backupTested != storageWallet!.backupTested) {
            storageWallet = storageWallet.copyWith(
              backupTested: eventWallet.backupTested,
            );
          }

          if (eventWallet.name != storageWallet.name) {
            storageWallet = storageWallet.copyWith(
              name: eventWallet.name,
            );
          }

          if (eventWallet.lastBackupTested != null &&
              eventWallet.lastBackupTested != storageWallet.lastBackupTested) {
            storageWallet = storageWallet.copyWith(
              lastBackupTested: eventWallet.lastBackupTested,
            );
          }
      }
    }

    final err = await _walletsStorageRepository.updateWallet(
      storageWallet!,
    );
    if (err != null) {
      locator<Logger>().log(err.toString(), printToConsole: true);
    }
    emit(state.copyWith(wallet: storageWallet));
    await Future.delayed(event.delaySync.ms);
    if (event.syncAfter) add(SyncWallet());
  }
}
