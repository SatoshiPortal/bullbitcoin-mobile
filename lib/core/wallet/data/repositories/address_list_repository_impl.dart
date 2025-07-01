import 'package:bb_mobile/core/wallet/data/datasources/address_history_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/address_details.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/address_list_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class AddressListRepositoryImpl implements AddressListRepository {
  final AddressHistoryDatasource _addressHistoryDatasource;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final WalletDatasource _bdkWallet;
  final WalletDatasource _lwkWallet;

  const AddressListRepositoryImpl({
    required AddressHistoryDatasource addressHistoryDatasource,
    required WalletMetadataDatasource walletMetadataDatasource,
    required WalletDatasource bdkWalletDatasource,
    required WalletDatasource lwkWalletDatasource,
  }) : _addressHistoryDatasource = addressHistoryDatasource,
       _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource;

  @override
  Future<List<AddressDetails>> getUsedReceiveAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  }) async {
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) {
      throw WalletError.walletNotFound(walletId);
    }

    final walletModel = WalletModel.fromMetadata(walletMetadata);
    final maxIndex = walletMetadata.lastAddressIndex;

    if (maxIndex < 0) return [];

    if (walletModel is PublicBdkWalletModel) {
      int calculatedOffset;
      int calculatedLimit;

      if (descending) {
        final start = (maxIndex - offset).clamp(0, maxIndex);
        final maxLimit = start + 1;
        final safeLimit = (limit ?? maxLimit).clamp(0, maxLimit);
        final end = (start - safeLimit + 1).clamp(0, start);
        calculatedOffset = end;
        calculatedLimit = (start - end + 1).clamp(0, safeLimit);
      } else {
        final start = offset.clamp(0, maxIndex);
        final maxLimit = maxIndex - start + 1;
        final safeLimit = (limit ?? maxLimit).clamp(0, maxLimit);
        final end = (start + safeLimit - 1).clamp(0, maxIndex);
        calculatedOffset = start;
        calculatedLimit = (end - start + 1).clamp(0, safeLimit);
      }

      final usedAddresses = await _bdkWallet.getReceiveAddresses(
        wallet: walletModel,
        limit: calculatedLimit,
        offset: calculatedOffset,
      );

      // Sorteer indien descending, want onderliggende functie geeft altijd oplopend
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

      return addressDetailsList;
    } else {
      walletModel as PublicLwkWalletModel;
      return [];
    }
  }

  @override
  Future<List<AddressDetails>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  }) async {
    final walletMetadata = await _walletMetadataDatasource.fetch(walletId);

    if (walletMetadata == null) {
      throw WalletError.walletNotFound(walletId);
    }

    return [];
  }
}
