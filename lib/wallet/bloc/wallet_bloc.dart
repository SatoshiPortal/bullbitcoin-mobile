import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required String saveDir,
    required this.settingsCubit,
    required this.walletSync,
    required this.secureStorage,
    required this.hiveStorage,
    required this.walletCreate,
    required this.walletRepository,
    required this.walletTransaction,
    required this.walletBalance,
    required this.walletAddress,
    this.fromStorage = true,
    Wallet? wallet,
  }) : super(WalletState(wallet: wallet)) {
    on<LoadWallet>(_loadWallet);
    on<UpdateWallet>(_updateWallet);
    on<GetBalance>(_getBalance);
    on<GetAddresses>(_getAddresses);
    on<ListTransactions>(_listTransactions);
    on<GetFirstAddress>(_getFirstAddress);
    on<GetNewAddress>(_getLastUnusedAddress);
    on<SyncWallet>(_syncWallet);
    add(LoadWallet(saveDir));
  }

  final SettingsCubit settingsCubit;
  final WalletSync walletSync;
  final WalletCreate walletCreate;
  final WalletRepository walletRepository;
  final WalletTx walletTransaction;
  final WalletBalance walletBalance;
  final WalletAddress walletAddress;

  final SecureStorage secureStorage;
  final HiveStorage hiveStorage;
  final bool fromStorage;

  void _loadWallet(LoadWallet event, Emitter<WalletState> emit) async {
    emit(state.copyWith(loadingWallet: true, errLoadingWallet: ''));

    Wallet wallet;

    if (fromStorage) {
      final (walletFromStorage, err) = await walletRepository.readWallet(
        walletHashId: event.saveDir,
        hiveStore: hiveStorage,
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

      wallet = walletFromStorage!;
    } else
      wallet = state.wallet!;

    emit(state.copyWith(wallet: wallet));

    if (state.bdkWallet == null) {
      final (bdkWallet, err) = await walletCreate.loadPublicBdkWallet(
        wallet,
      );
      if (err != null) {
        emit(
          state.copyWith(
            loadingWallet: false,
            errLoadingWallet: err.toString(),
          ),
        );
      }
      emit(state.copyWith(bdkWallet: bdkWallet));
    }

    emit(
      state.copyWith(
        loadingWallet: false,
        errLoadingWallet: '',
        wallet: wallet,
        name: wallet.name ?? '',
      ),
    );

    add(SyncWallet());
  }

  Future _syncWallet(SyncWallet event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;
    if (state.syncing) return;

    add(GetFirstAddress());
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

    final err = await walletSync.syncWallet(
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

    // if (!fromStorage) add(GetFirstAddress());
    add(GetBalance());
  }

  void _updateWallet(UpdateWallet event, Emitter<WalletState> emit) async {
    emit(state.copyWith(wallet: event.wallet));
  }

  void _getBalance(GetBalance event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    emit(state.copyWith(loadingBalance: true, errLoadingBalance: ''));

    final (w, err) = await walletBalance.getBalance(
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
      final errUpdate = await walletRepository.updateWallet(
        wallet: wallet,
        hiveStore: hiveStorage,
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

    final (wallet, err) = await walletTransaction.getTransactions(
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
      final errUpdating = await walletRepository.updateWallet(
        wallet: wallet!,
        hiveStore: hiveStorage,
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
    final (walletUpdated, wErr) = await walletAddress.loadAddresses(
      wallet: state.wallet!,
      bdkWallet: state.bdkWallet!,
    );
    if (wErr != null)
      emit(
        state.copyWith(
          errSyncingAddresses: wErr.toString(),
          syncingAddresses: false,
        ),
      );

    final (wallet, err) = await walletAddress.updateUtxos(
      bdkWallet: state.bdkWallet!,
      wallet: walletUpdated!,
    );
    if (err != null)
      emit(
        state.copyWith(
          errSyncingAddresses: err.toString(),
          syncingAddresses: false,
        ),
      );
    if (fromStorage) {
      final errUpdate = await walletRepository.updateWallet(
        wallet: wallet!,
        hiveStore: hiveStorage,
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
    final (address, err) = await walletAddress.peekIndex(state.bdkWallet!, 0);
    if (err != null) {
      emit(state.copyWith(errSyncingAddresses: err.toString()));
      return;
    }

    emit(state.copyWith(firstAddress: address!));
  }

  void _getLastUnusedAddress(GetNewAddress event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    final (newAddress, err) = await walletAddress.lastUnused(
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
