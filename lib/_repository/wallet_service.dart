// ignore_for_file: use_setters_to_change_properties
import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_network.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/locator.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';

// part 'wallet_service.freezed.dart';
// part 'wallet_service.g.dart';

// @freezed
// class WalletServiceData with _$WalletServiceData {
//   const factory WalletServiceData({
//     required Wallet wallet,
//     @Default(3) int loadingAttepmtsLeft,
//     @Default(true) bool loadingWallet,
//     @Default('') String errLoadingWallet,
//   }) = _WalletServiceData;
//   const WalletServiceData._();

//   factory WalletServiceData.fromJson(Map<String, dynamic> json) =>
//       _WalletServiceData.fromJson(json);
// }

class WalletService {
  WalletService({
    required Wallet wallet,
    required WalletsStorageRepository walletsStorageRepository,
    required InternalNetworkRepository internalNetworkRepository,
    // required InternalWalletsRepository walletsRepository,
    required WalletSync walletSync,
    required WalletBalance walletBalance,
    // required WalletAddress walletAddress,
    required WalletCreate walletCreate,
    required WalletTx walletTransaction,
    required NetworkRepository networkRepository,
    bool fromStorage = true,
  })  : _wallet = wallet,
        _walletsStorageRepository = walletsStorageRepository,
        _internalNetworkRepository = internalNetworkRepository,
        // _walletsRepository = walletsRepository,
        _walletSync = walletSync,
        _walletBalance = walletBalance,
        // _walletAddress = walletAddress,
        _walletCreate = walletCreate,
        _walletTransactionn = walletTransaction,
        _networkRepository = networkRepository,
        _fromStorage = fromStorage;

  Wallet _wallet;
  bool errLoading = false;
  int loadingAttemptsLeft = 3;
  int syncErrCount = 0;
  bool syncing = false;

  final bool _fromStorage;

  final WalletsStorageRepository _walletsStorageRepository;
  final InternalNetworkRepository _internalNetworkRepository;
  // final InternalWalletsRepository _walletsRepository;
  final WalletSync _walletSync;
  final WalletBalance _walletBalance;
  // final WalletAddress _walletAddress;
  final WalletCreate _walletCreate;
  final WalletTx _walletTransactionn;
  final NetworkRepository _networkRepository;

  Wallet get wallet => _wallet;

  Future<Err?> loadWallet() async {
    errLoading = false;
    final (w, err) = await _walletCreate.loadPublicWallet(
      saveDir: _wallet.getWalletStorageString(),
      wallet: _wallet,
      network: _wallet.network,
    );
    if (err != null) {
      errLoading = true;
      return err;
    }

    _wallet = w!;
    loadingAttemptsLeft = 3;
    return null;
  }

  Future<Err?> syncWallet() async {
    if (errLoading && loadingAttemptsLeft > 0) {
      loadingAttemptsLeft -= 1;
      final errLoad = await loadWallet();
      if (errLoad != null) return errLoad;
    }

    final isLiq = _wallet.isLiquid();

    final errNetwork = _internalNetworkRepository.checkNetworks2(isLiq);
    if (errNetwork != null) {
      await _networkRepository.loadNetworks();
      final errBC = await _networkRepository.setupBlockchain(isLiquid: isLiq);
      if (errBC != null) return errBC;
      final errNetwork2 = _internalNetworkRepository.checkNetworks2(isLiq);
      if (errNetwork2 != null) return errNetwork2;
    }

    final liqTxt = isLiq ? 'Instant' : 'Secure';
    locator<Logger>().log(
      'Start $liqTxt  Wallet Sync for ${_wallet.id}',
      printToConsole: true,
    );
    syncing = true;
    final err = await _walletSync.syncWallet(_wallet);
    syncing = false;
    locator<Logger>().log(
      'End $liqTxt Wallet Sync for ${_wallet.id}',
      printToConsole: true,
    );
    if (err != null) {
      if (err.message.toLowerCase().contains('panic') && syncErrCount < 5) {
        await _networkRepository.loadNetworks();
        final errBC2 =
            await _networkRepository.setupBlockchain(isLiquid: isLiq);
        syncErrCount += 1;
        if (errBC2 != null) return errBC2;
        final err2 = await _walletSync.syncWallet(_wallet);
        if (err2 != null) return err2;
      }

      locator<Logger>().log(err.toString());
    }

    syncErrCount = 0;
    return null;
  }

  Future updateWallet(
    Wallet wallet, {
    bool saveToStorage = true,
    required List<UpdateWalletTypes> updateTypes,
    bool syncAfter = false,
    int delaySync = 0,
  }) async {
    if (!saveToStorage) {
      _wallet = wallet;
      return;
    }

    if (updateTypes.contains(UpdateWalletTypes.load)) {
      final err = await _walletsStorageRepository.updateWallet(
        _wallet,
      );
      if (err != null) locator<Logger>().log(err.toString());
      _wallet = wallet;
      return;
    }

    var (storageWallet, errr) = await _walletsStorageRepository.readWallet(
      walletHashId: _wallet.getWalletStorageString(),
    );
    if (errr != null) locator<Logger>().log(errr.toString());
    if (storageWallet == null) return;

    for (final eventType in updateTypes) {
      switch (eventType) {
        case UpdateWalletTypes.load:
          break;
        case UpdateWalletTypes.balance:
          if (wallet.balance != null) {
            storageWallet = storageWallet!.copyWith(
              balance: wallet.balance,
              fullBalance: wallet.fullBalance,
            );
          }
        case UpdateWalletTypes.transactions:
          if (wallet.transactions.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              transactions: wallet.transactions,
            );
          }

          if (wallet.unsignedTxs.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              unsignedTxs: wallet.unsignedTxs,
            );
          }

        case UpdateWalletTypes.swaps:
          storageWallet = storageWallet!.copyWith(
            swaps: wallet.swaps,
            revKeyIndex: wallet.revKeyIndex,
            subKeyIndex: wallet.subKeyIndex,
          );

        case UpdateWalletTypes.addresses:
          if (wallet.myAddressBook.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              myAddressBook: wallet.myAddressBook,
            );
          }

          if (wallet.externalAddressBook != null &&
              wallet.externalAddressBook!.isNotEmpty) {
            storageWallet = storageWallet!.copyWith(
              externalAddressBook: wallet.externalAddressBook,
            );
          }

          if (wallet.lastGeneratedAddress != null) {
            storageWallet = storageWallet!.copyWith(
              lastGeneratedAddress: wallet.lastGeneratedAddress,
            );
          }

        case UpdateWalletTypes.utxos:
          storageWallet = storageWallet!.copyWith(utxos: wallet.utxos);

        case UpdateWalletTypes.settings:
          if (wallet.backupTested != storageWallet!.backupTested) {
            storageWallet = storageWallet.copyWith(
              backupTested: wallet.backupTested,
            );
          }

          if (wallet.name != storageWallet.name) {
            storageWallet = storageWallet.copyWith(
              name: wallet.name,
            );
          }

          if (wallet.lastBackupTested != null &&
              wallet.lastBackupTested != storageWallet.lastBackupTested) {
            storageWallet = storageWallet.copyWith(
              lastBackupTested: wallet.lastBackupTested,
            );
          }
      }

      final err = await _walletsStorageRepository.updateWallet(
        storageWallet!,
      );
      if (err != null) {
        locator<Logger>().log(err.toString(), printToConsole: true);
      }

      _wallet = storageWallet;
      await Future.delayed(Duration(milliseconds: delaySync));
      if (syncAfter) syncWallet();
    }
  }

  Future<Err?> getBalance() async {
    final (w, err) = await _walletBalance.getBalance(_wallet);
    if (err != null) return err;
    _wallet = w!.$1;
    updateWallet(
      wallet,
      saveToStorage: _fromStorage,
      updateTypes: [UpdateWalletTypes.balance],
    );
    return null;
  }

  Future<Err?> listTransactions() async {
    final (w, err) = await _walletTransactionn.getTransactions(_wallet);
    if (err != null) return err;
    _wallet = w!;
    updateWallet(
      wallet,
      saveToStorage: _fromStorage,
      updateTypes: [
        UpdateWalletTypes.transactions,
        UpdateWalletTypes.addresses,
        UpdateWalletTypes.transactions,
        UpdateWalletTypes.utxos,
      ],
    );
    return null;
  }

  void killSync() {
    _walletSync.cancelSync();
  }
}

WalletService createWalletService({required Wallet wallet}) {
  final walletsStorageRepository = locator<WalletsStorageRepository>();
  final internalNetworkkRepository = locator<InternalNetworkRepository>();
  // final walletsRepository = locator<InternalWalletsRepository>();
  final walletSync = locator<WalletSync>();
  final walletBalance = locator<WalletBalance>();
  // final walletAddress = locator<WalletAddress>();
  final walletCreate = locator<WalletCreate>();
  final walletTransaction = locator<WalletTx>();
  final networkRepository = locator<NetworkRepository>();

  return WalletService(
    wallet: wallet,
    walletsStorageRepository: walletsStorageRepository,
    internalNetworkRepository: internalNetworkkRepository,
    // walletsRepository: walletsRepository,
    walletSync: walletSync,
    walletBalance: walletBalance,
    // walletAddress: walletAddress,
    walletCreate: walletCreate,
    walletTransaction: walletTransaction,
    networkRepository: networkRepository,
  );
}

enum UpdateWalletTypes {
  load,
  balance,
  transactions,
  swaps,
  addresses,
  settings,
  utxos
}
