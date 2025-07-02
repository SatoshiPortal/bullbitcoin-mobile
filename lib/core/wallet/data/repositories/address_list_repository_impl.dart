/*import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_address_history_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

// TODO: Remove this class when these functions are implemented in the WalletAddressRepository.
class AddressListRepositoryImpl {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final WalletAddressHistoryDatasource _walletAddressHistoryDatasource;
  final BdkWalletDatasource _bdkWallet;
  // ignore: unused_field
  final LwkWalletDatasource _lwkWallet;

  const AddressListRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required WalletAddressHistoryDatasource walletAddressHistoryDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _walletAddressHistoryDatasource = walletAddressHistoryDatasource,
       _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource;

  @override
  Future<List<WalletAddress>> getUsedReceiveAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  }) async {
    final addressHistory = await _walletAddressHistoryDatasource.getByWalletId(
      walletId,
      limit: limit,
      offset: offset,
      descending: descending,
    );

    // Check if no indexes are missing based on the fact that the indexes should
    // be continuous and the first index in ascending order should be 0 and the
    // last index should be the maximum index, else get them from the wallet.
    // If more than one address is missing, don't fetch them one by one,
    // but fetch all that

    // Get the balance and number of transactions for each address.

    return [];

    /*final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) {
      throw WalletError.walletNotFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(walletMetadata);

    final maxIndex = walletMetadata.lastReceiveAddressIndex;
    if (maxIndex < 0) return [];

    // Calculate the offset and limit for the datasource based on the provided parameters.
    int datasourceOffset;
    int datasourceLimit;

    if (descending) {
      final start = (maxIndex - offset).clamp(0, maxIndex);
      final maxLimit = start + 1;
      final safeLimit = (limit ?? maxLimit).clamp(0, maxLimit);
      final end = (start - safeLimit + 1).clamp(0, start);
      datasourceOffset = end;
      datasourceLimit = (start - end + 1).clamp(0, safeLimit);
    } else {
      final start = offset.clamp(0, maxIndex);
      final maxLimit = maxIndex - start + 1;
      final safeLimit = (limit ?? maxLimit).clamp(0, maxLimit);
      final end = (start + safeLimit - 1).clamp(0, maxIndex);
      datasourceOffset = start;
      datasourceLimit = (end - start + 1).clamp(0, safeLimit);
    }

    if (walletModel is PublicBdkWalletModel) {
      final usedAddresses = await _bdkWallet.getReceiveAddresses(
        wallet: walletModel,
        offset: datasourceOffset,
        limit: datasourceLimit,
      );
    } else {
      walletModel as PublicLwkWalletModel;
      final usedAddresses = await _lwkWallet.getReceiveAddresses(
        wallet: walletModel,
        offset: datasourceOffset,
        limit: datasourceLimit,
      );
    }

    // Sort into descending or ascending order since the datasource returns
    //  the addresses in ascending order by index.
    final sortedAddresses =
        descending ? usedAddresses.reversed.toList() : usedAddresses;

    final addressDetailsList = await Future.wait(
      sortedAddresses.map((address) async {
        final (txs, balanceSat) =
            await (
              _bdkWallet.getTransactions(
                wallet: walletModel,
                toAddress: address.address,
              ),
              _bdkWallet.getAddressBalanceSat(
                address.address,
                wallet: walletModel,
              ),
            ).wait;

        return AddressDetails(
          address: address.address,
          walletId: walletId,
          index: address.index,
          balanceSat: balanceSat.toInt(),
          nrOfTransactions: txs.length,
        );
      }),
    );

    return addressDetailsList;*/
  }

  @override
  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  }) async {
    return [];
    /*
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) {
      throw WalletError.walletNotFound(walletId);
    }
    final walletModel = WalletModel.fromMetadata(walletMetadata);

    walletModel as PublicLwkWalletModel;
    final lastUsedChangeAddress =
        walletModel is PublicBdkWalletModel
            ? await _bdkWallet.getLastUnusedAddress(
              wallet: walletModel,
              isChange: true,
            )
            : await _lwkWallet.getLastUnusedAddress(
              wallet: walletModel,
              isChange: true,
            );
    final maxIndex = lastUsedChangeAddress.index;

    if (maxIndex < 0) return [];

    // Calculate the offset and limit for the datasource based on the provided parameters.
    int datasourceOffset;
    int datasourceLimit;

    if (descending) {
      final start = (maxIndex - offset).clamp(0, maxIndex);
      final maxLimit = start + 1;
      final safeLimit = (limit ?? maxLimit).clamp(0, maxLimit);
      final end = (start - safeLimit + 1).clamp(0, start);
      datasourceOffset = end;
      datasourceLimit = (start - end + 1).clamp(0, safeLimit);
    } else {
      final start = offset.clamp(0, maxIndex);
      final maxLimit = maxIndex - start + 1;
      final safeLimit = (limit ?? maxLimit).clamp(0, maxLimit);
      final end = (start + safeLimit - 1).clamp(0, maxIndex);
      datasourceOffset = start;
      datasourceLimit = (end - start + 1).clamp(0, safeLimit);
    }

    List<WalletAddressModel> usedAddresses;
    if (walletModel is PublicBdkWalletModel) {
      usedAddresses = await _bdkWallet.getChangeAddresses(
        wallet: walletModel,
        offset: datasourceOffset,
        limit: datasourceLimit,
      );
    } else {
      usedAddresses = await _lwkWallet.getChangeAddresses(
        wallet: walletModel,
        offset: datasourceOffset,
        limit: datasourceLimit,
      );
    }

    // Sort into descending or ascending order since the datasource returns
    //  the addresses in ascending order by index.
    final sortedAddresses =
        descending ? usedAddresses.reversed.toList() : usedAddresses;

    final addressDetailsList = await Future.wait(
      sortedAddresses.map((address) async {
        final (txs, balanceSat) =
            await (
              _bdkWallet.getTransactions(
                wallet: walletModel,
                toAddress: address.address,
              ),
              _bdkWallet.getAddressBalanceSat(
                address.address,
                wallet: walletModel,
              ),
            ).wait;

        return AddressDetails(
          address: address.address,
          walletId: walletId,
          index: address.index,
          isChange: true,
          balanceSat: balanceSat.toInt(),
          nrOfTransactions: txs.length,
        );
      }),
    );

    return addressDetailsList;*/
  }
}
*/
