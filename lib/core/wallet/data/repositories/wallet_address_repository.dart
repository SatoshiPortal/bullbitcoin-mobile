import 'dart:math';

import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/label_system.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class WalletAddressRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final LabelDatasource _labelDatasource;

  WalletAddressRepository({
    required WalletMetadataDatasource walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required LabelDatasource labelDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource,
       _labelDatasource = labelDatasource;

  Future<WalletAddress> getLastUnusedReceiveAddress({
    required String walletId,
  }) async {
    int index;
    String address;
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);

    if (walletModel is PublicBdkWalletModel) {
      final addressInfo = await _bdkWallet.getLastUnusedAddress(
        wallet: walletModel,
      );
      index = addressInfo.index;
      address = addressInfo.address;
    } else {
      final ({String confidential, int index, String standard}) addressInfo =
          await _lwkWallet.getLastUnusedAddress(wallet: walletModel);

      index = addressInfo.index;
      address = addressInfo.confidential;
    }

    var labels = await _labelDatasource.fetchByRef(address);

    while (labels.any((label) => LabelSystem.isSystemLabel(label.label))) {
      index++;
      if (walletModel is PublicBdkWalletModel) {
        address = await _bdkWallet.getAddressByIndex(
          index,
          wallet: walletModel,
        );
      } else {
        final addressInfo = await _lwkWallet.getAddressByIndex(
          index,
          wallet: walletModel,
        );
        address = addressInfo.confidential;
      }
      labels = await _labelDatasource.fetchByRef(address);
    }

    final walletAddressModel = WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final walletAddress = WalletAddressMapper.toEntity(
      walletAddressModel,
      labels: labels.map((label) => label.toEntity()).toList(),
    );

    return walletAddress;
  }

  Future<WalletAddress> generateNewReceiveAddress({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);
    int index;
    String address;
    if (walletModel is PublicBdkWalletModel) {
      // For BDK wallets, we can directly get a new address. As the index is
      // incremented automatically by calling getNewAddress. No need to check
      // for address re-use.
      final addressInfo = await _bdkWallet.getNewAddress(wallet: walletModel);
      index = addressInfo.index;
      address = addressInfo.address;
    } else {
      final lastUnusedAddressInfo = await _lwkWallet.getLastUnusedAddress(
        wallet: walletModel,
      );

      // Generate a new address with the next index.
      final addressInfo = await _lwkWallet.getAddressByIndex(
        lastUnusedAddressInfo.index + 1,
        wallet: walletModel,
      );

      index = addressInfo.index;
      address = addressInfo.confidential;
    }

    var labels = await _labelDatasource.fetchByRef(address);

    while (labels.any((label) => LabelSystem.isSystemLabel(label.label))) {
      index++;
      if (walletModel is PublicBdkWalletModel) {
        address = await _bdkWallet.getAddressByIndex(
          index,
          wallet: walletModel,
        );
      } else {
        final addressInfo = await _lwkWallet.getAddressByIndex(
          index,
          wallet: walletModel,
        );
        address = addressInfo.confidential;
      }
      labels = await _labelDatasource.fetchByRef(address);
    }

    final walletAddressModel = WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final walletAddress = WalletAddressMapper.toEntity(
      walletAddressModel,
      labels: labels.map((label) => label.toEntity()).toList(),
    );

    return walletAddress;
  }

  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
  }) async {
    // Fetch wallet metadata and history in parallel
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) throw WalletError.notFound(walletId);

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final isBdkWallet = walletModel is PublicBdkWalletModel;

    final from =
        fromIndex ??
        (isBdkWallet
            ? await _bdkWallet.getLastUnusedAddressIndex(wallet: walletModel)
            : await _lwkWallet.getLastUnusedAddressIndex(wallet: walletModel));
    final to = limit != null ? max(from - limit + 1, 0) : 0;

    // This is already in case we want to support both ascending and descending in the future
    final step = from <= to ? 1 : -1;
    final indexes = List.generate(
      (to - from).abs() + 1,
      (i) => from + i * step,
    );

    final addresses = await Future.wait(
      indexes.map((index) async {
        return await _generateAddressModel(
          index: index,
          walletModel: walletModel,
          walletId: walletId,
          isBdkWallet: isBdkWallet,
        );
      }),
    );

    // Enrich addresses with balance and transaction data in parallel
    return await _enrichAddresses(
      addresses: addresses,
      walletModel: walletModel,
      isBdkWallet: isBdkWallet,
    );
  }

  Future<WalletAddressModel> _generateAddressModel({
    required int index,
    required WalletModel walletModel,
    required String walletId,
    required bool isBdkWallet,
  }) async {
    final address = isBdkWallet
        ? await _bdkWallet.getAddressByIndex(index, wallet: walletModel)
        : (await _lwkWallet.getAddressByIndex(
            index,
            wallet: walletModel,
          )).confidential;

    return WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<WalletAddress>> _enrichAddresses({
    required List<WalletAddressModel> addresses,
    required WalletModel walletModel,
    required bool isBdkWallet,
  }) async {
    final allTransactions = isBdkWallet
        ? await _bdkWallet.getTransactions(wallet: walletModel)
        : await _lwkWallet.getTransactions(wallet: walletModel);
    final addressBalances = isBdkWallet
        ? await _bdkWallet.getAddressBalancesSat(wallet: walletModel)
        : await _lwkWallet.getAddressBalancesSat(wallet: walletModel);

    final enrichedAddresses = await Future.wait(
      addresses.map((addressModel) async {
        // Fetch balance and transactions in parallel
        final balanceSat = addressBalances[addressModel.address] ?? BigInt.zero;

        final transactions = allTransactions
            .where(
              (tx) => tx.outputs.any(
                (element) => element.address == addressModel.address,
              ),
            )
            .toList();

        return addressModel.copyWith(
          balanceSat: balanceSat.toInt(),
          nrOfTransactions: transactions.length,
          updatedAt: DateTime.now(),
        );
      }),
    );

    final result = <WalletAddress>[];
    for (var model in enrichedAddresses) {
      final labels = await _labelDatasource.fetchByRef(model.address);
      final entity = WalletAddressMapper.toEntity(
        model,
        labels: labels.map((label) => label.toEntity()).toList(),
      );
      result.add(entity);
    }

    return result;
  }

  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
    required bool descending,
  }) async {
    return [];
  }

  Future<WalletAddress> getAddressAtIndex({
    required String walletId,
    required int index,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);
    String address;

    if (walletModel is PublicBdkWalletModel) {
      address = await _bdkWallet.getAddressByIndex(index, wallet: walletModel);
    } else {
      final addressInfo = await _lwkWallet.getAddressByIndex(
        index,
        wallet: walletModel,
      );
      address = addressInfo.confidential;
    }

    final walletAddressModel = WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final labels = await _labelDatasource.fetchByRef(address);
    return WalletAddressMapper.toEntity(
      walletAddressModel,
      labels: labels.map((label) => label.toEntity()).toList(),
    );
  }
}
