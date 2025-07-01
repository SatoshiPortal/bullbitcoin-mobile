import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/address_details_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/address_details.dart';
import 'package:drift/drift.dart';

class AddressDetailsMapper {
  static AddressHistoryCompanion modelToSqliteCompanion(
    AddressDetailsModel model,
  ) {
    return AddressHistoryCompanion(
      address: Value(model.address),
      walletId: Value(model.walletId),
      index: Value(model.index),
      isChange: Value(model.isChange),
      isUsed: Value(model.isUsed),
      balanceSat: Value(model.balanceSat),
      nrOfTransactions: Value(model.nrOfTransactions),
      createdAt: Value(model.createdAt),
      updatedAt: Value(model.updatedAt),
    );
  }

  static AddressDetailsModel sqliteRowToModel(AddressHistoryRow row) {
    return AddressDetailsModel(
      address: row.address,
      walletId: row.walletId,
      index: row.index,
      isChange: row.isChange,
      isUsed: row.isUsed,
      balanceSat: row.balanceSat,
      nrOfTransactions: row.nrOfTransactions,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static AddressDetails modelToEntity(AddressDetailsModel model) {
    return AddressDetails(
      address: model.address,
      walletId: model.walletId,
      index: model.index,
      isChange: model.isChange,
      balanceSat: model.balanceSat,
      nrOfTransactions: model.nrOfTransactions,
    );
  }
}
