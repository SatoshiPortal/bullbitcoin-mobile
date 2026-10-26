import 'dart:math';

import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart'
    show WalletSourceKey, WalletSourceOperationCoordinator;

class WalletAddressRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final LabelsFacade _labelsFacade;
  final WalletSourceOperationCoordinator _coordinator;

  WalletAddressRepository({
    required this._walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._labelsFacade,
    required this._coordinator,
  }) : _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource;

  Future<WalletAddress> getLastRevealedReceiveAddress({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);
    return _coordinator.runExclusive(_sourceKey(walletModel), (_) async {
      int index;
      String address;
      if (walletModel is PublicBdkWalletModel) {
        final addressInfo = await _bdkWallet.getLastRevealedAddressOrNew(
          wallet: walletModel,
        );
        index = addressInfo.index;
        address = addressInfo.address;
      } else {
        final addressInfo = await _lwkWallet.getLastUnusedAddress(
          wallet: walletModel,
        );
        index = addressInfo.index;
        address = addressInfo.confidential;
      }

      var labels = await _labelsFacade.fetchByReference(address);
      while (labels.any((label) => LabelSystem.isSystemLabel(label.label))) {
        index++;
        address = await _addressAtIndex(index, walletModel);
        labels = await _labelsFacade.fetchByReference(address);
      }

      return WalletAddressMapper.toEntity(
        WalletAddressModel(
          walletId: walletId,
          index: index,
          address: address,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        labels: labels,
      );
    });
  }

  Future<WalletAddress> generateNewReceiveAddress({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);
    return _coordinator.runExclusive(_sourceKey(walletModel), (_) async {
      int index;
      String address;
      if (walletModel is PublicBdkWalletModel) {
        final addressInfo = await _bdkWallet.getNewAddress(wallet: walletModel);
        index = addressInfo.index;
        address = addressInfo.address;
      } else {
        final lastUnusedAddressInfo = await _lwkWallet.getLastUnusedAddress(
          wallet: walletModel,
        );
        final addressInfo = await _lwkWallet.getAddressByIndex(
          lastUnusedAddressInfo.index + 1,
          wallet: walletModel,
        );
        index = addressInfo.index;
        address = addressInfo.confidential;
      }

      var labels = await _labelsFacade.fetchByReference(address);
      while (labels.any((label) => LabelSystem.isSystemLabel(label.label))) {
        index++;
        address = await _addressAtIndex(index, walletModel);
        labels = await _labelsFacade.fetchByReference(address);
      }

      return WalletAddressMapper.toEntity(
        WalletAddressModel(
          walletId: walletId,
          index: index,
          address: address,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        labels: labels,
      );
    });
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

    return _coordinator.runExclusive(_sourceKey(walletModel), (_) async {
      final from =
          fromIndex ??
          (isBdkWallet
              ? await _bdkWallet.getLastRevealedAddressIndex(
                  wallet: walletModel,
                )
              : await _lwkWallet.getLastUnusedAddressIndex(
                  wallet: walletModel,
                ));
      final to = limit != null ? max(from - limit + 1, 0) : 0;

      // This is already in case we want to support both ascending and descending in the future
      final step = from <= to ? 1 : -1;
      final indexes = List.generate(
        (to - from).abs() + 1,
        (i) => from + i * step,
      );

      final addresses = await Future.wait(
        indexes.map((index) async {
          return _generateAddressModel(
            index: index,
            walletModel: walletModel,
            walletId: walletId,
            isBdkWallet: isBdkWallet,
            isChange: false,
          );
        }),
      );

      // Enrich addresses with balance and transaction data in parallel
      return _enrichAddresses(
        addresses: addresses,
        walletModel: walletModel,
        isBdkWallet: isBdkWallet,
      );
    });
  }

  Future<WalletAddressModel> _generateAddressModel({
    required int index,
    required WalletModel walletModel,
    required String walletId,
    required bool isBdkWallet,
    required bool isChange,
  }) async {
    final address = isBdkWallet
        ? await _bdkWallet.getAddressByIndex(
            index,
            wallet: walletModel,
            isChange: isChange,
          )
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
      final labels = await _labelsFacade.fetchByReference(model.address);
      final entity = WalletAddressMapper.toEntity(model, labels: labels);
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
    // Fetch wallet metadata and history in parallel
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) throw WalletError.notFound(walletId);

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final isBdkWallet = walletModel is PublicBdkWalletModel;

    if (!isBdkWallet) {
      // LWK currently doesn't support fetching
      // change addresses separately, so we return an empty list here.
      return [];
    }

    return _coordinator.runExclusive(_sourceKey(walletModel), (_) async {
      final from =
          fromIndex ??
          await _bdkWallet.getLastRevealedAddressIndex(
            wallet: walletModel,
            isChange: true,
          );
      if (from < 0) return <WalletAddress>[];
      final to = limit != null ? max(from - limit + 1, 0) : 0;

      // This is already in case we want to support both ascending and descending in the future
      final step = from <= to ? 1 : -1;
      final indexes = List.generate(
        (to - from).abs() + 1,
        (i) => from + i * step,
      );

      final addresses = await Future.wait(
        indexes.map((index) async {
          return _generateAddressModel(
            index: index,
            walletModel: walletModel,
            walletId: walletId,
            isBdkWallet: isBdkWallet,
            isChange: true,
          );
        }),
      );

      // Enrich addresses with balance and transaction data in parallel
      return _enrichAddresses(
        addresses: addresses,
        walletModel: walletModel,
        isBdkWallet: isBdkWallet,
      );
    });
  }

  Future<WalletAddress> getAddressAtIndex({
    required String walletId,
    required int index,
    required bool isChange,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(metadata);
    return _coordinator.runExclusive(_sourceKey(walletModel), (_) async {
      final address = await _addressAtIndex(
        index,
        walletModel,
        isChange: isChange,
      );
      final walletAddressModel = WalletAddressModel(
        walletId: walletId,
        index: index,
        address: address,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final labels = await _labelsFacade.fetchByReference(address);
      return WalletAddressMapper.toEntity(walletAddressModel, labels: labels);
    });
  }

  WalletSourceKey _sourceKey(WalletModel wallet) => WalletSourceKey(
    wallet.id,
    wallet is PublicBdkWalletModel ? 'bitcoin' : 'liquid',
    wallet.isTestnet ? 'testnet' : 'mainnet',
  );

  Future<String> _addressAtIndex(
    int index,
    WalletModel wallet, {
    bool isChange = false,
  }) async {
    if (wallet is PublicBdkWalletModel) {
      return _bdkWallet.getAddressByIndex(
        index,
        wallet: wallet,
        isChange: isChange,
      );
    }
    final address = await _lwkWallet.getAddressByIndex(index, wallet: wallet);
    return address.confidential;
  }
}
