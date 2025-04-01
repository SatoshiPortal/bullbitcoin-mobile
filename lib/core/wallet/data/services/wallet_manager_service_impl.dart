import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/core/bitcoin/data/repository/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/core/bitcoin/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/liquid/data/repository/lwk_wallet_repository_impl.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/tx_input.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class WalletManagerServiceImpl implements WalletManagerService {
  final WalletMetadataRepository _walletMetadataRepository;
  final SeedRepository _seedRepository;
  final ElectrumServerRepository _electrumServerRepository;
  final Map<String, WalletRepository> _wallets = {};

  WalletManagerServiceImpl({
    required WalletMetadataRepository walletMetadataRepository,
    required SeedRepository seedRepository,
    required ElectrumServerRepository electrumServerRepository,
  })  : _walletMetadataRepository = walletMetadataRepository,
        _seedRepository = seedRepository,
        _electrumServerRepository = electrumServerRepository;

  @override
  Future<bool> doDefaultWalletsExist({required Environment environment}) async {
    final wallets = await _walletMetadataRepository.getAll();

    final defaultWalletsOfEnvironment = wallets
        .where(
          (wallet) =>
              wallet.isDefault &&
              (wallet.network.isMainnet && environment.isMainnet ||
                  wallet.network.isTestnet && environment.isTestnet),
        )
        .toList();

    // Check if there are exactly 2 default wallets for the current environment
    if (defaultWalletsOfEnvironment.length != 2) {
      return false;
    }

    // Make sure that one is bitcoin and the other is liquid
    if (defaultWalletsOfEnvironment[0].network.isBitcoin !=
        defaultWalletsOfEnvironment[1].network.isLiquid) {
      return false;
    }

    // Make sure the wallets were created correctly and are usable
    for (final wallet in defaultWalletsOfEnvironment) {
      if (wallet.source != WalletSource.mnemonic) {
        return false;
      }
      final hasSeed = await _seedRepository.exists(wallet.masterFingerprint);
      if (!hasSeed) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> initExistingWallets() async {
    final walletsMetadata = await _walletMetadataRepository.getAll();

    for (final metadata in walletsMetadata) {
      final wallet =
          await _createPublicWalletRepository(walletMetadata: metadata);
      await _registerWalletRepository(id: metadata.id, wallet: wallet);
    }
  }

  @override
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label = '',
    bool isDefault = false,
  }) async {
    final metadata = await _walletMetadataRepository.deriveFromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: label,
      isDefault: isDefault,
    );
    final wallet =
        await _createPublicWalletRepository(walletMetadata: metadata);

    // Now that both the metadata as the wallet datasource instance were created successfully
    //  we can store both the wallet metadata as the seed
    await Future.wait([
      _walletMetadataRepository.store(metadata),
      _seedRepository.store(
        fingerprint: seed.masterFingerprint,
        seed: seed,
      ),
    ]);

    // Now that the wallet is created and stored, register it here in the manager
    //  for use in the app.
    await _registerWalletRepository(id: metadata.id, wallet: wallet);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await wallet.getBalance();
    //final lastTransactions = await wallet.getTransactions(offset: 0, limit: 3);

    // Return the created wallet entity
    return Wallet(
      id: metadata.id,
      label: metadata.label,
      network: metadata.network,
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: metadata.source,
      balanceSat: balance.totalSat,
    );
  }

  @override
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  }) async {
    final metadata = await _walletMetadataRepository.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );

    final wallet =
        await _createPublicWalletRepository(walletMetadata: metadata);

    await _walletMetadataRepository.store(metadata);

    await _registerWalletRepository(id: metadata.id, wallet: wallet);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await wallet.getBalance();

    // Return the created wallet entity
    return Wallet(
      id: metadata.id,
      label: metadata.label,
      network: metadata.network,
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: metadata.source,
      balanceSat: balance.totalSat,
    );
  }

  @override
  Future<Wallet> getWallet(String id) async {
    final wallet = _wallets[id];
    final metadata = await _walletMetadataRepository.get(id);

    if (wallet == null || metadata == null) {
      throw WalletNotFoundException(id);
    }

    final balance = await wallet.getBalance();

    return Wallet(
      id: metadata.id,
      label: metadata.label,
      network: metadata.network,
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: metadata.source,
      balanceSat: balance.totalSat,
    );
  }

  @override
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
  }) async {
    final wallets = <Wallet>[];
    for (final walletEntry in _wallets.entries) {
      final metadata = await _walletMetadataRepository.get(walletEntry.key);

      if (metadata == null) {
        continue;
      }

      // Filter out wallets that don't match the given criteria
      if (environment != null &&
              metadata.network.isMainnet != environment.isMainnet ||
          onlyDefaults == true && !metadata.isDefault ||
          onlyBitcoin == true && !metadata.network.isBitcoin ||
          onlyLiquid == true && !metadata.network.isLiquid) {
        continue;
      }

      final balance = await walletEntry.value.getBalance();

      wallets.add(
        Wallet(
          id: metadata.id,
          label: metadata.label,
          network: metadata.network,
          isDefault: metadata.isDefault,
          masterFingerprint: metadata.masterFingerprint,
          xpubFingerprint: metadata.xpubFingerprint,
          scriptType: metadata.scriptType,
          xpub: metadata.xpub,
          externalPublicDescriptor: metadata.externalPublicDescriptor,
          internalPublicDescriptor: metadata.internalPublicDescriptor,
          source: metadata.source,
          balanceSat: balance.totalSat,
        ),
      );
    }

    return wallets;
  }

  @override
  Future<Address> getAddressByIndex({
    required String walletId,
    required int index,
  }) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final address = await wallet.getAddressByIndex(index);
    final addressWithOptionalData =
        await _addOptionalAddressData(address, wallet: wallet);

    return addressWithOptionalData;
  }

  @override
  Future<Balance> getBalance({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final balance = await wallet.getBalance();

    return balance;
  }

  @override
  Future<Address> getLastUnusedAddress({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final address = await wallet.getLastUnusedAddress();

    final addressWithOptionalData =
        await _addOptionalAddressData(address, wallet: wallet);

    return addressWithOptionalData;
  }

  @override
  Future<Address> getNewAddress({required String walletId}) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final address = await wallet.getNewAddress();
    // final addressWithOptionalData =
    //     await _addOptionalAddressData(address, wallet: wallet);

    return address;
  }

  @override
  Future<Wallet> sync({required String walletId}) async {
    final wallet = _wallets[walletId];
    final metadata = await _walletMetadataRepository.get(walletId);

    if (wallet == null || metadata == null) {
      throw WalletNotFoundException(walletId);
    }

    final electrumServer = await _electrumServerRepository.getElectrumServer(
      network: metadata.network,
    );
    try {
      await wallet.sync(electrumServer: electrumServer);
    } catch (e) {
      debugPrint(e.toString());
      return getWallet(walletId);
    }
    return getWallet(walletId);
  }

  @override
  Future<List<Wallet>> syncAll({Environment? environment}) async {
    final walletIds = List<String>.from(_wallets.keys);

    for (final walletId in walletIds) {
      final metadata = await _walletMetadataRepository.get(walletId);
      if (metadata == null ||
          (environment != null &&
              metadata.network.isMainnet != environment.isMainnet)) {
        continue;
      }

      await sync(walletId: walletId);
    }

    return getWallets(environment: environment);
  }

  @override
  Future<List<Utxo>> getUnspentUtxos({required String walletId}) {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    return wallet.listUnspent();
  }

  @override
  Future<bool> isOwnedByWallet({
    required String walletId,
    required Uint8List scriptBytes,
  }) {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    if (wallet is BitcoinWalletRepository) {
      final bitcoinWallet = wallet as BitcoinWalletRepository;
      return bitcoinWallet.isMine(scriptBytes);
    }

    throw UnsupportedError(
      'Ability to check if an input is owned, is currently only supported for Bitcoin wallets',
    );
  }

  @override
  Future<Transaction> buildUnsigned({
    required String walletId,
    required String address,
    BigInt? amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
    List<TxInput>? unspendableInputs,
    bool? drain,
    List<TxInput>? selectableInputs,
    bool replaceByFees = true,
  }) async {
    final wallet = await _getWalletWithPrivateKey(walletId);

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    if (wallet is BitcoinWalletRepository) {
      final bitcoinWallet = wallet as BitcoinWalletRepository;

      return bitcoinWallet.buildUnsigned(
        address: address,
        amountSat: amountSat,
        absoluteFeeSat: absoluteFeeSat,
        feeRateSatPerVb: feeRateSatPerVb,
        unspendableInputs: unspendableInputs,
        drain: drain,
        selectedInputs: selectableInputs,
        replaceByFees: replaceByFees,
      );
    }

    throw UnsupportedError(
      'Ability to build a PSBT is only supported for Bitcoin wallets',
    );
  }

  @override
  Future<Transaction> sign({
    required String walletId,
    required Transaction tx,
  }) async {
    final wallet = await _getWalletWithPrivateKey(walletId);

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    if (wallet is BitcoinWalletRepository) {
      final bitcoinWallet = wallet as BitcoinWalletRepository;
      return bitcoinWallet.sign(tx);
    }

    throw UnsupportedError(
      'Ability to sign a PSBT is currently only supported for Bitcoin wallets',
    );
  }

  Future<WalletRepository?> _getWalletWithPrivateKey(String id) async {
    final walletMetadata = await _walletMetadataRepository.get(id);

    if (walletMetadata == null) {
      return null;
    }

    return _createPrivateWalletRepository(walletMetadata: walletMetadata);
  }

  Future<void> _registerWalletRepository({
    required String id,
    required WalletRepository wallet,
  }) async {
    if (_wallets.containsKey(id)) {
      return;
    }

    _wallets[id] = wallet;
  }

  Future<String> _getWalletDbPath(String walletId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$walletId';
  }

  Future<WalletRepository> _createPublicWalletRepository({
    required WalletMetadata walletMetadata,
  }) async {
    final dbPath = await _getWalletDbPath(walletMetadata.id);
    if (walletMetadata.network.isBitcoin) {
      return BdkWalletRepositoryImpl.public(
        externalDescriptor: walletMetadata.externalPublicDescriptor,
        internalDescriptor: walletMetadata.internalPublicDescriptor,
        isTestnet: walletMetadata.network.isTestnet,
        dbPath: dbPath,
      );
    } else {
      final electrumServer = await _electrumServerRepository.getElectrumServer(
        network: walletMetadata.network,
      );

      return LwkWalletRepositoryImpl.public(
        ctDescriptor: walletMetadata.externalPublicDescriptor,
        dbPath: dbPath,
        isTestnet: walletMetadata.network.isTestnet,
        electrumServer: electrumServer,
      );
    }
  }

  Future<WalletRepository> _createPrivateWalletRepository({
    required WalletMetadata walletMetadata,
  }) async {
    final dbPath = await _getWalletDbPath(walletMetadata.id);
    final seed = await _seedRepository.get(walletMetadata.masterFingerprint);

    if (seed is! MnemonicSeed) {
      throw WrongSeedTypeException(
        'Seed type is not MnemonicSeed: ${seed.runtimeType}',
      );
    }

    final mnemonic = seed.mnemonicWords.join(' ');

    if (walletMetadata.network.isBitcoin) {
      return BdkWalletRepositoryImpl.private(
        scriptType: walletMetadata.scriptType,
        mnemonic: mnemonic,
        passphrase: seed.passphrase,
        isTestnet: walletMetadata.network.isTestnet,
        dbPath: dbPath,
      );
    } else {
      final electrumServer = await _electrumServerRepository.getElectrumServer(
        network: walletMetadata.network,
      );
      return LwkWalletRepositoryImpl.private(
        mnemonic: mnemonic,
        dbPath: dbPath,
        isTestnet: walletMetadata.network.isTestnet,
        electrumServer: electrumServer,
      );
    }
  }

  @override
  Future<List<Address>> getUsedReceiveAddresses({
    required String walletId,
    int? limit,
    int? offset,
  }) async {
    final wallet = _wallets[walletId];

    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }

    final lastUnusedAddress = await wallet.getLastUnusedAddress();
    final maxIndex =
        max((offset ?? 0) + (limit ?? 0), lastUnusedAddress.index - 1);

    final addresses = <Address>[];
    for (int i = offset ?? 0; i <= maxIndex; i++) {
      final address = await wallet.getAddressByIndex(i);

      final balanceSat = await wallet.getAddressBalanceSat(address.address);
      if (wallet is LwkWalletRepositoryImpl) {
        addresses.add(
          Address.liquid(
            index: address.index,
            standard: address.standardAddress,
            confidential: address.address,
            kind: AddressKind.external,
            state: AddressStatus.used,
            balanceSat: balanceSat,
          ),
        );
      } else {
        addresses.add(
          Address.bitcoin(
            index: address.index,
            address: address.address,
            kind: AddressKind.external,
            state: AddressStatus.used,
            balanceSat: balanceSat,
          ),
        );
      }
    }

    return addresses;
  }

  Future<Address> _addOptionalAddressData(
    Address address, {
    required WalletRepository wallet,
    AddressKind kind = AddressKind.external,
  }) async {
    final isUsed = await wallet.isAddressUsed(address.address);
    final balanceSat = await wallet.getAddressBalanceSat(address.address);

    final addressWithOptionalData = address.copyWith(
      state: isUsed ? AddressStatus.used : AddressStatus.unused,
      balanceSat: balanceSat,
      kind: kind,
    );

    return addressWithOptionalData;
  }

  @override
  Future<List<BaseWalletTransaction>> getBaseTransactions({
    required String walletId,
  }) async {
    final wallet = _wallets[walletId];
    if (wallet == null) {
      throw WalletNotFoundException(walletId);
    }
    return await wallet.getTransactions(walletId);
  }
}

class WrongSeedTypeException implements Exception {
  final String message;

  WrongSeedTypeException(this.message);
}

class WalletNotFoundException implements Exception {
  final String message;

  const WalletNotFoundException(this.message);
}

class MissingAmountException implements Exception {
  final String message;

  const MissingAmountException(this.message);
}
