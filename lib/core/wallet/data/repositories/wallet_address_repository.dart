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
    await _walletAddressHistoryDatasource.store(walletAddressModel);

    final walletAddress = WalletAddressMapper.toEntity(walletAddressModel);

    return walletAddress;
  }

  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  }) async {
    // ignore: unused_local_variable
    final addressHistory = await _walletAddressHistoryDatasource.getByWalletId(
      walletId,
      limit: limit,
      offset: offset,
      descending: descending,
    );

    // Check if no indexes are missing based on the fact that the indexes should
    // be continuous and the first index in ascending order should be 0 and the
    // last index should be the maximum index and taking the limit and offset into account,
    //  else get them from the wallet.
    // If more than one address is missing, don't fetch them one by one,
    // but fetch all that

    // Get the balance and number of transactions for each address.

    return [];
  }

  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    required bool descending,
  }) {
    // TODO: implement getUsedChangeAddresses
    throw UnimplementedError();
  }
}
