import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_address_history_datasource.dart';
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
  final WalletAddressHistoryDatasource _walletAddressHistoryDatasource;

  WalletAddressRepository({
    required WalletMetadataDatasource walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required WalletAddressHistoryDatasource walletAddressHistoryDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource,
       _walletAddressHistoryDatasource = walletAddressHistoryDatasource;

  Future<WalletAddress> getNewReceiveAddress({required String walletId}) async {
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
      ({String confidential, int index, String standard}) addressInfo =
          await _lwkWallet.getNewAddress(wallet: walletModel);

      // Since lwk doesn't increment the index until funds are received on an address,
      //  we need to check for address re-use ourselves, as the user might have
      //  already seen and shared the address without having received funds on it yet.
      final addressInHistory = await _walletAddressHistoryDatasource.get(
        addressInfo.confidential,
      );

      if (addressInHistory != null) {
        // Address is already in history, so it has been generated before.
        // Get the latest index from the history.
        final latestWalletAddressInHistory =
            await _walletAddressHistoryDatasource.getByWalletId(
              walletId,
              limit: 1,
              offset: 0,
              descending: true,
            );
        // Generate a new address with the next index.
        addressInfo = await _lwkWallet.getAddressByIndex(
          latestWalletAddressInHistory.first.index + 1,
          wallet: walletModel,
        );
      }

      index = addressInfo.index;
      address = addressInfo.confidential;
    }

    final walletAddressModel = WalletAddressModel(
      walletId: walletId,
      index: index,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Store the address in the wallet address history so we don't generate it again
    // and so we can track its usage.
    await _walletAddressHistoryDatasource.create(walletAddressModel);

    final walletAddress = WalletAddressMapper.toEntity(walletAddressModel);

    return walletAddress;
  }

  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
  }) async {
    // Fetch wallet metadata and history in parallel
    final (walletMetadata, addressHistory) =
        await (
          _walletMetadataDatasource.fetch(walletId),
          _walletAddressHistoryDatasource.getByWalletId(
            walletId,
            limit: limit,
            offset: offset,
            descending: true,
          ),
        ).wait;

    if (walletMetadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final isBdkWallet = walletModel is PublicBdkWalletModel;

    if (addressHistory.isEmpty) {
      return [];
    }

    // Fill any gaps in the address history
    final completeHistory = await _fillAddressGaps(
      addressHistory: addressHistory,
      walletModel: walletModel,
      walletId: walletId,
      isBdkWallet: isBdkWallet,
    );

    // Sort and limit the addresses as requested
    completeHistory.sort((a, b) => b.index.compareTo(a.index));
    final trimmedHistory =
        limit != null && completeHistory.length > limit
            ? completeHistory.sublist(0, limit)
            : completeHistory;

    // Enrich addresses with balance and transaction data in parallel
    return _enrichAddresses(
      addressHistory: trimmedHistory,
      walletModel: walletModel,
      isBdkWallet: isBdkWallet,
    );
  }

  Future<List<WalletAddressModel>> _fillAddressGaps({
    required List<WalletAddressModel> addressHistory,
    required WalletModel walletModel,
    required String walletId,
    required bool isBdkWallet,
  }) async {
    // Find all gaps in one pass (history is in descending order)
    final gaps = <int>[];
    for (int i = 1; i < addressHistory.length; i++) {
      final previousIndex = addressHistory[i - 1].index;
      final currentIndex = addressHistory[i].index;

      // Check for gaps between consecutive addresses
      for (int j = currentIndex + 1; j < previousIndex; j++) {
        gaps.add(j);
      }
    }

    if (gaps.isEmpty) return addressHistory;

    // Generate all missing addresses in parallel
    final missingAddresses = await Future.wait(
      gaps.map(
        (index) => _generateAddressModel(
          index: index,
          walletModel: walletModel,
          walletId: walletId,
          isBdkWallet: isBdkWallet,
        ),
      ),
    );

    // Store all missing addresses
    await Future.wait(
      missingAddresses.map(
        (model) => _walletAddressHistoryDatasource.create(model),
      ),
    );

    // Return a new list with all addresses combined
    return [...addressHistory, ...missingAddresses];
  }

  Future<WalletAddressModel> _generateAddressModel({
    required int index,
    required WalletModel walletModel,
    required String walletId,
    required bool isBdkWallet,
  }) async {
    final address =
        isBdkWallet
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
    required List<WalletAddressModel> addressHistory,
    required WalletModel walletModel,
    required bool isBdkWallet,
  }) async {
    final enrichedAddresses = await Future.wait(
      addressHistory.map((addressModel) async {
        // Fetch balance and transactions in parallel
        final (balanceSat, transactions) =
            isBdkWallet
                ? await (
                  _bdkWallet.getAddressBalanceSat(
                    addressModel.address,
                    wallet: walletModel,
                  ),
                  _bdkWallet.getTransactions(
                    wallet: walletModel,
                    toAddress: addressModel.address,
                  ),
                ).wait
                : await (
                  _lwkWallet.getAddressBalanceSat(
                    addressModel.address,
                    wallet: walletModel,
                  ),
                  _lwkWallet.getTransactions(
                    wallet: walletModel,
                    toAddress: addressModel.address,
                  ),
                ).wait;

        // Update if balance or transaction count changed
        if (addressModel.balanceSat != balanceSat.toInt() ||
            addressModel.nrOfTransactions != transactions.length) {
          addressModel = addressModel.copyWith(
            balanceSat: balanceSat.toInt(),
            nrOfTransactions: transactions.length,
            updatedAt: DateTime.now(),
          );
          // It is important to use `update` instead of `create` here,
          // as we are updating an existing address in the history.
          await _walletAddressHistoryDatasource.update(addressModel);
        }

        // TODO: Get labels for the addresses
        return WalletAddressMapper.toEntity(addressModel, labels: <String>[]);
      }),
    );
    return enrichedAddresses;
  }

  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    required bool descending,
  }) async {
    return [];
  }
}
