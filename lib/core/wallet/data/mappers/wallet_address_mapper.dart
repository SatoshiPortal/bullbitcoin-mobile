import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:drift/drift.dart';

class WalletAddressMapper {
  static WalletAddressesCompanion toSqliteCompanion(WalletAddressModel model) {
    return WalletAddressesCompanion(
      address: Value(model.address),
      walletId: Value(model.walletId),
      index: Value(model.index),
      isChange: Value(model.isChange),
      balanceSat: Value(model.balanceSat),
      nrOfTransactions: Value(model.nrOfTransactions),
      createdAt: Value(model.createdAt),
      updatedAt: Value(model.updatedAt),
    );
  }

  static WalletAddressModel fromSqliteRow(WalletAddressRow row) {
    return WalletAddressModel(
      address: row.address,
      walletId: row.walletId,
      index: row.index,
      isChange: row.isChange,
      balanceSat: row.balanceSat,
      nrOfTransactions: row.nrOfTransactions,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static WalletAddress toEntity(
    WalletAddressModel walletAddressModel, {
    List<String>? labels,
  }) {
    return WalletAddress(
      walletId: walletAddressModel.walletId,
      index: walletAddressModel.index,
      address: walletAddressModel.address,
      keyChain:
          walletAddressModel.isChange
              ? WalletAddressKeyChain.internal
              : WalletAddressKeyChain.external,
      balanceSat: walletAddressModel.balanceSat,
      nrOfTransactions: walletAddressModel.nrOfTransactions,
      //highestPreviousBalanceSat: walletAddressModel.highestPreviousBalanceSat,
      labels: labels,
      createdAt: walletAddressModel.createdAt,
      updatedAt: walletAddressModel.updatedAt,
    );
  }

  static WalletAddressModel fromEntity(WalletAddress walletAddress) {
    return WalletAddressModel(
      address: walletAddress.address,
      walletId: walletAddress.walletId,
      index: walletAddress.index,
      isChange: walletAddress.keyChain == WalletAddressKeyChain.internal,
      balanceSat: walletAddress.balanceSat,
      nrOfTransactions: walletAddress.nrOfTransactions,
      createdAt: walletAddress.createdAt,
      updatedAt: walletAddress.updatedAt,
    );
  }
}
