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
      final addressInHistory = await _walletAddressHistoryDatasource.fetch(
        addressInfo.confidential,
      );

      if (addressInHistory != null) {
        // Address is already in history, so it has been generated before.
        // Get the latest index from the history.
        final latestWalletAddressInHistory =
            await _walletAddressHistoryDatasource.getByWalletId(
              walletId,
              limit: 1,
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
    await _walletAddressHistoryDatasource.store(walletAddressModel);

    final walletAddress = WalletAddressMapper.toEntity(walletAddressModel);

    return walletAddress;
  }

  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
  }) async {
    // Fetch wallet metadata and history in parallel
    final (walletMetadata, addressHistory) =
        await (
          _walletMetadataDatasource.fetch(walletId),
          _walletAddressHistoryDatasource.getByWalletId(
            walletId,
            limit: limit,
            fromIndex: fromIndex,
            descending: true,
          ),
        ).wait;

    if (walletMetadata == null) {
      throw WalletError.notFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final isBdkWallet = walletModel is PublicBdkWalletModel;

    if (addressHistory.isEmpty) {
      int startIndex;
      if (fromIndex == null) {
        // Get the last used address from the wallet datasource since nothing is in history.

        startIndex =
            isBdkWallet
                ? await _bdkWallet.getLastUnusedAddressIndex(
                  wallet: walletModel,
                )
                : await _lwkWallet.getLastUnusedAddressIndex(
                  wallet: walletModel,
                );

        if (startIndex == 0) {
          // This means no addresses have been generated yet.
          return [];
        }
      } else {
        startIndex = fromIndex;
      }

      // Generate the last unused address and add it to the history to start from there.
      addressHistory.add(
        await _generateAddressModel(
          index: startIndex,
          walletModel: walletModel,
          walletId: walletId,
          isBdkWallet: isBdkWallet,
        ),
      );
    }

    // Fill any gaps in the address history
    final completeHistory = await _fillAddressGaps(
      addressHistory: addressHistory,
      walletModel: walletModel,
      walletId: walletId,
      isBdkWallet: isBdkWallet,
      limit: limit,
      fromIndex: fromIndex,
    );

    // Sort and limit the addresses as requested
    completeHistory.sort((a, b) => b.index.compareTo(a.index));
    final trimmedHistory =
        limit != null && completeHistory.length > limit
            ? completeHistory.sublist(0, limit)
            : completeHistory;

    // Enrich addresses with balance and transaction data in parallel
    final enrichedAddresses = await _enrichAddresses(
      addressHistory: trimmedHistory,
      walletModel: walletModel,
      isBdkWallet: isBdkWallet,
    );

    // Return the enriched addresses
    return enrichedAddresses.map((model) {
      return WalletAddressMapper.toEntity(model);
    }).toList();
  }

  Future<List<WalletAddressModel>> _fillAddressGaps({
    required List<WalletAddressModel> addressHistory,
    required WalletModel walletModel,
    required String walletId,
    required bool isBdkWallet,
    int? limit,
    int? fromIndex,
  }) async {
    final gaps = <int>[];

    // Find gaps above the highest index in the history
    if (fromIndex != null && addressHistory.first.index < fromIndex) {
      for (int i = addressHistory.first.index + 1; i <= fromIndex; i++) {
        gaps.add(i);
      }
    }

    // Find all other gaps in one pass (history is in descending order)
    for (int i = 1; i < addressHistory.length; i++) {
      final previousIndex = addressHistory[i - 1].index;
      final currentIndex = addressHistory[i].index;

      // Check for gaps between consecutive addresses
      for (int j = currentIndex + 1; j < previousIndex; j++) {
        gaps.add(j);
      }
    }

    // If a limit is set, complete until the limit is reached.
    final lastAddressHistoryIndex = addressHistory.last.index;
    if (limit != null && gaps.length + addressHistory.length < limit) {
      // Fill gaps until we reach the limit
      for (
        int i = lastAddressHistoryIndex - 1;
        gaps.length + addressHistory.length < limit && i >= 0;
        i--
      ) {
        gaps.add(i);
      }
    }
    // If no limit is set, make sure to fill until index 0.
    else if (limit == null && lastAddressHistoryIndex > 0) {
      for (int i = lastAddressHistoryIndex - 1; i >= 0; i--) {
        gaps.add(i);
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
        (model) => _walletAddressHistoryDatasource.store(model),
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

  // ignore: unused_element
  Future<List<WalletAddressModel>> _enrichAddresses({
    required List<WalletAddressModel> addressHistory,
    required WalletModel walletModel,
    required bool isBdkWallet,
  }) async {
    final allTransactions =
        isBdkWallet
            ? await _bdkWallet.getTransactions(wallet: walletModel)
            : await _lwkWallet.getTransactions(wallet: walletModel);

    final enrichedAddresses = await Future.wait(
      addressHistory.map((addressModel) async {
        // Fetch balance and transactions in parallel
        final balanceSat =
            isBdkWallet
                ? await _bdkWallet.getAddressBalanceSat(
                  addressModel.address,
                  wallet: walletModel,
                )
                : await _lwkWallet.getAddressBalanceSat(
                  addressModel.address,
                  wallet: walletModel,
                );

        final transactions =
            allTransactions
                .where(
                  (tx) => tx.outputs.any(
                    (element) => element.address == addressModel.address,
                  ),
                )
                .toList();

        // Update if balance or transaction count changed
        if (addressModel.balanceSat != balanceSat.toInt() ||
            addressModel.nrOfTransactions != transactions.length) {
          addressModel = addressModel.copyWith(
            balanceSat: balanceSat.toInt(),
            nrOfTransactions: transactions.length,
            updatedAt: DateTime.now(),
          );
          await _walletAddressHistoryDatasource.store(addressModel);
        }

        // TODO: Get labels for the addresses
        return addressModel;
      }),
    );
    return enrichedAddresses;
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

    return WalletAddressMapper.toEntity(walletAddressModel);
  }
}
