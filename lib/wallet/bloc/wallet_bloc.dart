import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    required this.walletUpdate,
    required this.networkCubit,
    this.fromStorage = true,
    Wallet? wallet,
  }) : super(WalletState(wallet: wallet)) {
    on<LoadWallet>(_loadWallet);
    on<SyncWallet>(_syncWallet, transformer: droppable());
    on<UpdateWallet>(_updateWallet, transformer: sequential());

    on<GetBalance>(_getBalance);
    // on<GetAddresses>(_getAddresses);
    on<ListTransactions>(_listTransactions);
    on<GetFirstAddress>(_getFirstAddress);
    on<UpdateUtxos>(_updateUtxos);

    add(LoadWallet(saveDir));
  }

  final SettingsCubit settingsCubit;
  final WalletSync walletSync;
  final WalletCreate walletCreate;
  final WalletRepository walletRepository;
  final WalletTx walletTransaction;
  final WalletBalance walletBalance;
  final WalletAddress walletAddress;
  final WalletUpdate walletUpdate;
  final NetworkCubit networkCubit;

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
        name: wallet.name ?? '',
      ),
    );

    add(UpdateWallet(wallet, saveToStorage: fromStorage, updateTypes: [UpdateWalletTypes.load]));
    await Future.delayed(50.ms);
    add(GetFirstAddress());
    add(SyncWallet());
  }

  Future _syncWallet(SyncWallet event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;
    if (state.syncing) return;

    emit(
      state.copyWith(
        syncing: true,
        errSyncing: '',
      ),
    );

    if (networkCubit.state.blockchain == null) {
      await networkCubit.loadNetworks();
      await Future.delayed(const Duration(milliseconds: 300));
      if (networkCubit.state.blockchain == null) {
        emit(state.copyWith(syncing: false));
        return;
      }
    }

    final blockchain = networkCubit.state.blockchain;
    final bdkWallet = state.bdkWallet!;

    final sameNetwork = state.wallet?.isSameNetwork(networkCubit.state.testnet) ?? false;
    if (!sameNetwork) {
      emit(state.copyWith(syncing: false));
      return;
    }

    locator<Logger>().log('Start Wallet Sync for ' + (state.wallet?.sourceFingerprint ?? ''));

    final (bdkW, err) = await walletSync.syncWallet(
      blockChain: blockchain!,
      bdkWallet: bdkWallet,
    );

    locator<Logger>().log('End Wallet Sync for ' + (state.wallet?.sourceFingerprint ?? ''));

    if (err != null) {
      emit(
        state.copyWith(
          errSyncing: err.toString(),
          syncing: false,
        ),
      );
      locator<Logger>().log(err.toString());
      return;
    }

    emit(state.copyWith(syncing: false, bdkWallet: bdkW));
    await Future.delayed(100.ms);

    if (!fromStorage) add(GetFirstAddress());
    add(GetBalance());

    emit(state.copyWith(syncing: false));
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

    final (wallet, _) = w!;

    add(UpdateWallet(wallet, saveToStorage: fromStorage, updateTypes: [UpdateWalletTypes.balance]));

    emit(
      state.copyWith(
        loadingBalance: false,
        // balance: balance,
      ),
    );

    add(ListTransactions());
  }

  void _listTransactions(ListTransactions event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;

    emit(
      state.copyWith(
        syncingAddresses: true,
        errSyncingAddresses: '',
      ),
    );

    final (walletWithAddresses, err1) = await walletAddress.loadAddresses(
      wallet: state.wallet!,
      bdkWallet: state.bdkWallet!,
    );
    if (err1 != null) {
      emit(
        state.copyWith(
          errSyncingAddresses: err1.toString(),
          syncingAddresses: false,
        ),
      );
      return;
    }
    // final (walletWithAddresses, err2) = await walletAddress.loadChangeAddresses(
    //   wallet: walletWithDepositAddresses!,
    //   bdkWallet: state.bdkWallet!,
    // );
    // if (err2 != null) {
    //   emit(
    //     state.copyWith(
    //       errSyncingAddresses: err2.toString(),
    //       syncingAddresses: false,
    //     ),
    //   );
    //   return;
    // }
    emit(state.copyWith(loadingTxs: true, errLoadingWallet: ''));

    final (walletWithTxs, err3) = await walletTransaction.getTransactions(
      bdkWallet: state.bdkWallet!,
      wallet: walletWithAddresses!,
    );

    if (err3 != null) {
      emit(
        state.copyWith(
          errLoadingWallet: err3.toString(),
          loadingTxs: false,
        ),
      );
      return;
    }

    final (walletWithTxAndAddresses, err4) =
        await walletUpdate.updateAddressesFromTxs(walletWithTxs!);

    if (err4 != null) {
      emit(
        state.copyWith(
          errLoadingWallet: err4.toString(),
          loadingTxs: false,
        ),
      );
      return;
    }

    emit(state.copyWith(loadingTxs: false));

    emit(
      state.copyWith(
        syncingAddresses: true,
        errSyncingAddresses: '',
      ),
    );

    final (walletWithUtxos, err5) = await walletAddress.updateUtxos(
      bdkWallet: state.bdkWallet!,
      wallet: walletWithTxAndAddresses!,
    );
    if (err5 != null) {
      emit(
        state.copyWith(
          errSyncingAddresses: err5.toString(),
          syncingAddresses: false,
        ),
      );
      return;
    }

    add(
      UpdateWallet(
        walletWithUtxos!,
        saveToStorage: fromStorage,
        updateTypes: [UpdateWalletTypes.addresses, UpdateWalletTypes.transactions],
      ),
    );
  }

  void _updateUtxos(UpdateUtxos event, Emitter<WalletState> emit) async {}

  void _getFirstAddress(GetFirstAddress event, Emitter<WalletState> emit) async {
    if (state.bdkWallet == null) return;
    final (address, err) = await walletAddress.peekIndex(state.bdkWallet!, 0);
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

  void _updateWallet(UpdateWallet event, Emitter<WalletState> emit) async {
    if (!event.saveToStorage) {
      emit(state.copyWith(wallet: event.wallet));
      return;
    }

    if (event.updateTypes.contains(UpdateWalletTypes.load)) {
      final err = await walletRepository.updateWallet(
        wallet: event.wallet,
        hiveStore: hiveStorage,
      );
      if (err != null) locator<Logger>().log(err.toString());

      emit(state.copyWith(wallet: event.wallet));
      return;
    }

    final eventWallet = event.wallet;
    var (storageWallet, errr) = await walletRepository.readWallet(
      walletHashId: state.wallet!.getWalletStorageString(),
      hiveStore: hiveStorage,
    );
    if (errr != null) locator<Logger>().log(errr.toString());

    for (final eventType in event.updateTypes)
      switch (eventType) {
        case UpdateWalletTypes.load:
          break;
        case UpdateWalletTypes.balance:
          if (eventWallet.balance != null)
            storageWallet = storageWallet!.copyWith(
              balance: eventWallet.balance,
              fullBalance: eventWallet.fullBalance,
            );
        case UpdateWalletTypes.transactions:
          if (eventWallet.transactions.isNotEmpty)
            storageWallet = storageWallet!.copyWith(
              transactions: eventWallet.transactions,
            );
          if (eventWallet.unsignedTxs.isNotEmpty)
            storageWallet = storageWallet!.copyWith(
              unsignedTxs: eventWallet.unsignedTxs,
            );
        case UpdateWalletTypes.addresses:
          if (eventWallet.myAddressBook.isNotEmpty)
            storageWallet = storageWallet!.copyWith(
              myAddressBook: eventWallet.myAddressBook,
            );

          if (eventWallet.externalAddressBook != null &&
              eventWallet.externalAddressBook!.isNotEmpty)
            storageWallet = storageWallet!.copyWith(
              externalAddressBook: eventWallet.externalAddressBook,
            );

          if (eventWallet.lastGeneratedAddress != null)
            storageWallet = storageWallet!.copyWith(
              lastGeneratedAddress: eventWallet.lastGeneratedAddress,
            );

        case UpdateWalletTypes.settings:
          if (eventWallet.backupTested != storageWallet!.backupTested)
            storageWallet = storageWallet.copyWith(
              backupTested: eventWallet.backupTested,
            );

          if (eventWallet.name != storageWallet.name)
            storageWallet = storageWallet.copyWith(
              name: eventWallet.name,
            );

          if (eventWallet.lastBackupTested != null &&
              eventWallet.lastBackupTested != storageWallet.lastBackupTested)
            storageWallet = storageWallet.copyWith(
              lastBackupTested: eventWallet.lastBackupTested,
            );
      }

    final err = await walletRepository.updateWallet(
      wallet: storageWallet!,
      hiveStore: hiveStorage,
    );
    if (err != null) locator<Logger>().log(err.toString(), printToConsole: true);
    emit(state.copyWith(wallet: storageWallet));
  }
}
