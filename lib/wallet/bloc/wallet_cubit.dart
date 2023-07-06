import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletCubit extends Cubit<WalletState> {
  WalletCubit({
    required String saveDir,
    required this.settingsCubit,
    required this.walletRead,
    required this.storage,
    required this.walletCreate,
    required this.walletUpdate,
    this.fromStorage = true,
    Wallet? wallet,
  }) : super(WalletState(wallet: wallet)) {
    loadWallet(saveDir);
  }

  // final WalletStorage walletStorage;
  final SettingsCubit settingsCubit;
  final WalletRead walletRead;
  final WalletCreate walletCreate;
  final WalletUpdate walletUpdate;
  final IStorage storage;
  final bool fromStorage;

  Future<void> loadWallet(String saveDir) async {
    emit(state.copyWith(loadingWallet: true, errLoadingWallet: ''));

    Wallet wallet;

    if (fromStorage) {
      final (w, err) = await walletRead.getWalletDetails(
        saveDir: saveDir,
        storage: storage,
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

      wallet = w!;
    } else
      wallet = state.wallet!;

    emit(state.copyWith(wallet: wallet));

    if (state.bdkWallet == null) {
      final (wallets, err) =
          await walletCreate.loadBdkWallet(wallet, fromStorage: fromStorage);
      if (err != null) {
        emit(
          state.copyWith(
            loadingWallet: false,
            errLoadingWallet: err.toString(),
          ),
        );
        return;
      }
      final (w, bdkWallet) = wallets!;
      wallet = w;
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

    syncWallet();
  }

  void sync() {
    syncWallet();
  }

  Future<void> syncWallet() async {
    if (state.bdkWallet == null) return;

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

    final (receivePort, err) = await walletRead.sync2(
      blockchain,
      bdkWallet,
    );
    if (err != null) {
      emit(
        state.copyWith(
          errSyncing: err.toString(),
          syncing: false,
        ),
      );
    }

    await receivePort!.first.whenComplete(
      () async => {
        await getBalance(),
        await getAddresses(),
        listTransactions(),
        if (!fromStorage) getFirstAddress(),
        emit(state.copyWith(syncing: false))
      },
    );

    // final _ = await walletRead.sync2(
    //   blockchain,
    //   bdkWallet,
    // );
    // if (!synced) return;

    // emit(state.copyWith(syncing: false));

    // final _ = await compute(syncW, (bdkWallet, blockchain));

    // final resultPort = ReceivePort();
    // await Isolate.spawn(
    //   (data) async {
    //     await data.$1.sync(data.$2);
    //     Isolate.exit(data.$3, true);
    //   },
    //   (state.bdkWallet!, blockchain, resultPort.sendPort),
    // );
    // await resultPort.first;

    // await compute(
    //   (data) async => {await data.$1.sync(data.$2)},
    //   (state.bdkWallet!, blockchain),
    // );

    // walletRead.syncWallet(bdkWallet: state.bdkWallet!, blockChain: blockchain);

    // final err = await walletRead.syncWallet(bdkWallet: state.bdkWallet!, blockChain: blockchain);
    // if (err != null) throw err;
    // // await Isolate.run(
    // //   () {
    // //     state.bdkWallet!.sync(blockchain);
    // //   },
    // // );

    // emit(state.copyWith(syncing: false));
    // });
  }

  Future<void> getBalance() async {
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
  }

  void updateWallet(Wallet wallet) {
    emit(state.copyWith(wallet: wallet));
  }

  Future<void> getAddresses() async {
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

  Future<void> listTransactions() async {
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
  }

  void getFirstAddress() async {
    if (state.bdkWallet == null) return;

    final (address, err) =
        await walletUpdate.getAddressAtIdx(state.bdkWallet!, 0);
    if (err != null) {
      emit(state.copyWith(errSyncingAddresses: err.toString()));
      return;
    }

    emit(state.copyWith(firstAddress: address));
  }
}

// Future<bool> syncW(dynamic obj) async {
//   final m = obj as (bdk.Wallet, bdk.Blockchain);
//   final wallet = m.$1;
//   final blockchain = m.$2;
//   await wallet.sync(blockchain);
//   return true;
// }

//
//
//

//
//
//

//
//
//

//
//
//

//
//
//

//
//
//

//
//
//

//
//
//

//
//
//

// 1685008409
// 1685008363817

// ArgumentError (Invalid argument(s): Illegal argument in isolate message: (object implements Finalizable - Library:'package:bdk_flutter/src/generated/bridge_definitions.dart' Class: WalletInstance))

//
