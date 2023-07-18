import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required String saveDir,
    required this.settingsCubit,
    required this.walletRead,
    required this.secureStorage,
    required this.storage,
    required this.walletCreate,
    required this.walletUpdate,
    this.fromStorage = true,
    Wallet? wallet,
  }) : super(WalletState(wallet: wallet)) {
    on<LoadWallet>(_loadWallet);
    on<UpdateWallet>(_updateWallet);
    on<GetBalance>(_getBalance);
    on<GetAddresses>(_getAddresses);
    on<ListTransactions>(_listTransactions);
    on<GetFirstAddress>(_getFirstAddress);
    on<GetNewAddress>(_getNewAddress);
    on<SyncWallet>(_syncWallet);
    add(LoadWallet(saveDir));
  }

  final SettingsCubit settingsCubit;
  final WalletRead walletRead;
  final WalletCreate walletCreate;
  final WalletUpdate walletUpdate;
  final IStorage secureStorage;
  final IStorage storage;
  final bool fromStorage;

  void _loadWallet(LoadWallet event, Emitter<WalletState> emit) async {
    emit(state.copyWith(loadingWallet: true, errLoadingWallet: ''));

    Wallet wallet;

    if (fromStorage) {
      final (sensitiveWallet, err) = await walletRead.getWalletDetails(
        saveDir: event.saveDir,
        storage: secureStorage,
      );
      if (err != null) {
        emit(
          state.copyWith(
            loadingWallet: false,
            errLoadingWallet: err.toString(),
          ),
        );
        return;
      }

      wallet = sensitiveWallet!;
    } else
      wallet = state.wallet!;

    emit(state.copyWith(wallet: wallet));

    if (state.bdkWallet == null) {
      final (wallets, err) = await walletCreate.loadBdkWallet(
        wallet,
        fromStorage: fromStorage,
        onlyPublic: true,
      );
      if (err != null) {
        emit(
          state.copyWith(
            loadingWallet: false,
            errLoadingWallet: err.toString(),
          ),
        );
      }
      final (w, bdkWallet) = wallets!;
      wallet = w;
      emit(state.copyWith(bdkWallet: bdkWallet));
    }

    final (notSensitiveWallet, err) = await walletRead.getWalletDetails(
      saveDir: event.saveDir,
      storage: storage,
    );

    emit(
      state.copyWith(
        loadingWallet: false,
        errLoadingWallet: '',
        wallet: err == null ? notSensitiveWallet : wallet,
        name: wallet.name ?? '',
      ),
    );

    add(SyncWallet());
  }

  Future _syncWallet(SyncWallet event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;
    if (state.syncing) return;

    add(GetNewAddress());
    await Future.delayed(const Duration(milliseconds: 300));

    emit(
      state.copyWith(
        syncing: true,
        errSyncing: '',
      ),
    );

    if (settingsCubit.state.blockchain == null) {
      await settingsCubit.loadNetworks();
      await Future.delayed(const Duration(milliseconds: 300));
      if (settingsCubit.state.blockchain == null) {
        emit(state.copyWith(syncing: false));
        return;
      }
    }

    final blockchain = settingsCubit.state.blockchain!;
    final bdkWallet = state.bdkWallet!;

    final err = await walletRead.syncWallet(
      blockChain: blockchain,
      bdkWallet: bdkWallet,
    );

    if (err != null) {
      emit(
        state.copyWith(
          errSyncing: err.toString(),
          syncing: false,
        ),
      );
    }

    emit(state.copyWith(syncing: false));

    if (!fromStorage) add(GetFirstAddress());
    add(GetBalance());
  }

  void _updateWallet(UpdateWallet event, Emitter<WalletState> emit) async {
    emit(state.copyWith(wallet: event.wallet));
  }

  void _getBalance(GetBalance event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    emit(state.copyWith(loadingBalance: true, errLoadingBalance: ''));

    final (w, err) = await walletRead.getBalance(
      bdkWallet: state.bdkWallet!,
      wallet: state.wallet!,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingBalance: err.toString(),
          loadingBalance: false,
        ),
      );
      return;
    }

    final (wallet, balance) = w!;
    if (fromStorage) {
      final errUpdate = await walletUpdate.updateWallet(
        wallet: wallet,
        storage: storage,
        walletRead: walletRead,
      );

      if (errUpdate != null) {
        emit(
          state.copyWith(
            errLoadingBalance: errUpdate.toString(),
            loadingBalance: false,
          ),
        );
        return;
      }
    }
    emit(
      state.copyWith(
        loadingBalance: false,
        balance: balance,
        wallet: wallet,
      ),
    );

    add(ListTransactions());
  }

  void _listTransactions(ListTransactions event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    emit(state.copyWith(loadingTxs: true, errLoadingWallet: ''));

    final (wallet, err) = await walletRead.getTransactions(
      bdkWallet: state.bdkWallet!,
      wallet: state.wallet!,
    );

    if (err != null) {
      emit(
        state.copyWith(
          errLoadingWallet: err.toString(),
          loadingTxs: false,
        ),
      );
      return;
    }

    if (fromStorage) {
      final errUpdating = await walletUpdate.updateWallet(
        wallet: wallet!,
        storage: storage,
        walletRead: walletRead,
      );
      if (errUpdating != null) {
        emit(
          state.copyWith(
            errLoadingWallet: errUpdating.toString(),
            loadingTxs: false,
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        loadingTxs: false,
        wallet: wallet,
      ),
    );

    add(GetAddresses());
  }

  void _getAddresses(GetAddresses event, Emitter<WalletState> emit) async {
    emit(
      state.copyWith(
        syncingAddresses: true,
        errSyncingAddresses: '',
      ),
    );
    final (wallet, err) = await walletRead.getAddresses(
      bdkWallet: state.bdkWallet!,
      wallet: state.wallet!,
    );
    if (err != null)
      emit(
        state.copyWith(
          errSyncingAddresses: err.toString(),
          syncingAddresses: false,
        ),
      );
    if (fromStorage) {
      final errUpdate = await walletUpdate.updateWallet(
        wallet: wallet!,
        storage: storage,
        walletRead: walletRead,
      );
      if (errUpdate != null) {
        emit(
          state.copyWith(
            errSyncingAddresses: errUpdate.toString(),
            syncingAddresses: false,
          ),
        );
        return;
      }
    }
    emit(
      state.copyWith(
        wallet: wallet,
        syncingAddresses: false,
      ),
    );
  }

  void _getFirstAddress(GetFirstAddress event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    final (address, err) = await walletUpdate.getAddressAtIdx(state.bdkWallet!, 0);
    if (err != null) {
      emit(state.copyWith(errSyncingAddresses: err.toString()));
      return;
    }

    emit(state.copyWith(newAddress: (address: address!, index: 0)));
  }

  void _getNewAddress(GetNewAddress event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    final (newAddress, err) = await walletUpdate.getNewAddress(
      wallet: state.wallet!,
      bdkWallet: state.bdkWallet!,
    );
    if (err != null) {
      emit(state.copyWith(errSyncingAddresses: err.toString()));
      return;
    }

    final address = newAddress!.address;
    final index = newAddress.index;
    emit(
      state.copyWith(
        newAddress: (
          address: address,
          index: index,
        ),
      ),
    );
  }
}
