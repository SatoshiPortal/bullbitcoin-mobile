import 'dart:async';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_network.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/locator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'wallet_service.freezed.dart';
part 'wallet_service.g.dart';

@freezed
class WalletServiceData with _$WalletServiceData {
  const factory WalletServiceData({
    required Wallet wallet,
    @Default(3) int loadingAttemptsLeft,
    @Default(false) bool errLoading,
    @Default(0) int syncErrCount,
    @Default(false) bool syncing,
  }) = _WalletServiceData;
  const WalletServiceData._();

  factory WalletServiceData.fromJson(Map<String, dynamic> json) =>
      _WalletServiceData.fromJson(json);
}

class WalletService {
  WalletService({
    required Wallet wallet,
    required WalletsStorageRepository walletsStorageRepository,
    required InternalNetworkRepository internalNetworkRepository,
    required WalletSync walletSync,
    required WalletBalance walletBalance,
    required WalletAddress walletAddress,
    required WalletCreate walletCreate,
    required WalletTx walletTransaction,
    required NetworkRepository networkRepository,
    bool fromStorage = false,
  })  : _walletsStorageRepository = walletsStorageRepository,
        _internalNetworkRepository = internalNetworkRepository,
        _walletSync = walletSync,
        _walletBalance = walletBalance,
        _walletAddress = walletAddress,
        _walletCreate = walletCreate,
        _walletTransactionn = walletTransaction,
        _networkRepository = networkRepository,
        _fromStorage = fromStorage,
        _data = BehaviorSubject<WalletServiceData>.seeded(
          WalletServiceData(wallet: wallet),
        );

  // Lock lock = Lock(reentrant: true);

  final BehaviorSubject<WalletServiceData> _data;

  Stream<WalletServiceData> get dataStream => _data.asBroadcastStream();
  // Stream<Wallet> get walletStream => _data.stream.map((e) => e.wallet);

  // WalletServiceData get data => _data.value;

  final bool _fromStorage;

  final WalletsStorageRepository _walletsStorageRepository;
  final InternalNetworkRepository _internalNetworkRepository;

  final WalletSync _walletSync;
  final WalletBalance _walletBalance;
  final WalletAddress _walletAddress;
  final WalletCreate _walletCreate;
  final WalletTx _walletTransactionn;
  final NetworkRepository _networkRepository;

  Wallet get wallet => _data.value.wallet;

  void dispose() {
    _data.close();
  }

  Future<Err?> loadWallet({bool syncAfter = false}) async {
    _data.add(_data.value.copyWith(errLoading: false));
    final (w, err) = await _walletCreate.loadPublicWallet(
      saveDir: _data.value.wallet.getWalletStorageString(),
      wallet: _data.value.wallet,
      network: _data.value.wallet.network,
    );
    if (err != null) {
      _data.add(_data.value.copyWith(errLoading: true));
      return err;
    }

    _data.add(
      _data.value.copyWith(
        wallet: w!,
        loadingAttemptsLeft: 3,
      ),
    );

    if (syncAfter) await syncWallet();

    return null;
  }

  Future<Err?> syncWallet() async {
    if (_data.value.errLoading && _data.value.loadingAttemptsLeft > 0) {
      _data.add(
        _data.value.copyWith(
          loadingAttemptsLeft: _data.value.loadingAttemptsLeft - 1,
        ),
      );
      final errLoad = await loadWallet();
      if (errLoad != null) return errLoad;
    }

    final isLiq = _data.value.wallet.isLiquid();

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
      'Start $liqTxt  Wallet Sync for ${_data.value.wallet.id}',
      printToConsole: true,
    );

    _data.add(_data.value.copyWith(syncing: true));
    final err = await _walletSync.syncWallet(_data.value.wallet);
    _data.add(_data.value.copyWith(syncing: false));
    locator<Logger>().log(
      'End $liqTxt Wallet Sync for ${_data.value.wallet.id} - err: $err',
      printToConsole: true,
    );

    if (err != null) {
      if (err.message.toLowerCase().contains('panic') &&
          _data.value.syncErrCount < 5) {
        await _networkRepository.loadNetworks();
        final errBC2 =
            await _networkRepository.setupBlockchain(isLiquid: isLiq);

        _data.add(
          _data.value.copyWith(syncErrCount: _data.value.syncErrCount + 1),
        );
        if (errBC2 != null) return errBC2;
        final err2 = await _walletSync.syncWallet(_data.value.wallet);
        if (err2 != null) return err2;
      }

      locator<Logger>().log(err.toString());
    }

    _data.add(_data.value.copyWith(syncErrCount: 0));

    scheduleMicrotask(() async {
      // await Future.wait([
      // if (!_fromStorage) await getFirstAddress();
      await getBalance();
      await listTransactions();
      // ]);
    });

    return null;
  }

  Future updateWallet(
    Wallet wallet, {
    bool saveToStorage = true,
    required List<UpdateWalletTypes> updateTypes,
    bool syncAfter = false,
    int delaySync = 0,
  }) async {
    // return lock.synchronized(() async {
    if (!saveToStorage) {
      _data.add(_data.value.copyWith(wallet: wallet));
      return;
    }

    if (updateTypes.contains(UpdateWalletTypes.load)) {
      final err = await _walletsStorageRepository.updateWallet(
        _data.value.wallet,
      );
      if (err != null) locator<Logger>().log(err.toString());

      _data.add(_data.value.copyWith(wallet: wallet));
      return;
    }

    var (storageWallet, errr) = await _walletsStorageRepository.readWallet(
      walletHashId: _data.value.wallet.getWalletStorageString(),
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
          if (wallet.physicalBackupTested !=
              storageWallet!.physicalBackupTested) {
            storageWallet = storageWallet.copyWith(
              physicalBackupTested: wallet.physicalBackupTested,
            );
          }

          if (wallet.name != storageWallet.name) {
            storageWallet = storageWallet.copyWith(
              name: wallet.name,
            );
          }

          if (wallet.lastPhysicalBackupTested != null &&
              wallet.lastPhysicalBackupTested !=
                  storageWallet.lastPhysicalBackupTested) {
            storageWallet = storageWallet.copyWith(
              lastPhysicalBackupTested: wallet.lastPhysicalBackupTested,
            );
          }
        case UpdateWalletTypes.bip85Paths:
          if (wallet.bip85Derivations != storageWallet!.bip85Derivations) {
            storageWallet = storageWallet.copyWith(
              bip85Derivations: wallet.bip85Derivations,
            );
          }
      }

      final err = await _walletsStorageRepository.updateWallet(
        storageWallet!,
      );
      if (err != null) {
        locator<Logger>().log(err.toString(), printToConsole: true);
      }

      _data.add(_data.value.copyWith(wallet: storageWallet));
      await Future.delayed(Duration(milliseconds: delaySync));
      if (syncAfter) syncWallet();
    }
    // });
  }

  Future<Err?> getBalance() async {
    final (w, err) = await _walletBalance.getBalance(_data.value.wallet);
    if (err != null) return err;

    _data.add(_data.value.copyWith(wallet: w!.$1));
    await updateWallet(
      wallet,
      saveToStorage: _fromStorage,
      updateTypes: [UpdateWalletTypes.balance],
    );
    return null;
  }

  Future<Err?> listTransactions() async {
    final (w, err) =
        await _walletTransactionn.getTransactions(_data.value.wallet);
    if (err != null) return err;

    _data.add(_data.value.copyWith(wallet: w!));
    await updateWallet(
      wallet,
      saveToStorage: _fromStorage,
      updateTypes: [
        UpdateWalletTypes.transactions,
        UpdateWalletTypes.addresses,
        UpdateWalletTypes.utxos,
      ],
    );
    return null;
  }

  Future<Err?> getFirstAddress() async {
    final (address, err) =
        await _walletAddress.peekIndex(wallet: _data.value.wallet, idx: 0);

    if (err != null) return err;

    _data.add(
      _data.value.copyWith(
        wallet: _data.value.wallet.copyWith(
          firstAddress: Address(
            address: address!,
            index: 0,
            kind: AddressKind.deposit,
            state: AddressStatus.unused,
          ),
        ),
      ),
    );
    return null;
  }

  void killSync() {
    _walletSync.cancelSync();
  }
}

WalletService createWalletService({
  required Wallet wallet,
  bool fromStorage = false,
}) {
  final walletsStorageRepository = locator<WalletsStorageRepository>();
  final internalNetworkkRepository = locator<InternalNetworkRepository>();

  final walletSync = locator<WalletSync>();
  final walletBalance = locator<WalletBalance>();
  final walletAddress = locator<WalletAddress>();
  final walletCreate = locator<WalletCreate>();
  final walletTransaction = locator<WalletTx>();
  final networkRepository = locator<NetworkRepository>();

  return WalletService(
    wallet: wallet,
    walletsStorageRepository: walletsStorageRepository,
    internalNetworkRepository: internalNetworkkRepository,
    walletSync: walletSync,
    walletBalance: walletBalance,
    walletAddress: walletAddress,
    walletCreate: walletCreate,
    walletTransaction: walletTransaction,
    networkRepository: networkRepository,
    fromStorage: fromStorage,
  );
}

enum UpdateWalletTypes {
  load,
  balance,
  transactions,
  swaps,
  addresses,
  settings,
  utxos,
  bip85Paths,
}
