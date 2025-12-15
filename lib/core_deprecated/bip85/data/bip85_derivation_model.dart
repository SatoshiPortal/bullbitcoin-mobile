import 'package:bb_mobile/core_deprecated/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/infra/database/tables/bip85_derivations_table.dart';

class Bip85DerivationModel {
  final String path;
  final String xprvFingerprint;
  final String? alias;
  final Bip85StatusColumn status;
  final Bip85ApplicationColumn application;

  Bip85DerivationModel({
    required this.path,
    required this.xprvFingerprint,
    required this.alias,
    required this.status,
    required this.application,
  });

  int get index {
    // Future applications may format the index differently.
    switch (application) {
      default:
        final lastPart = path.replaceAll("'", "").split('/').last;
        final index = int.parse(lastPart);
        return index;
    }
  }

  factory Bip85DerivationModel.fromSqlite(Bip85DerivationRow row) {
    return Bip85DerivationModel(
      path: row.path,
      xprvFingerprint: row.xprvFingerprint,
      alias: row.alias,
      status: row.status,
      application: row.application,
    );
  }

  factory Bip85DerivationModel.fromEntity(Bip85DerivationEntity entity) {
    return Bip85DerivationModel(
      path: entity.path,
      xprvFingerprint: entity.xprvFingerprint,
      alias: entity.alias,
      status: Bip85StatusColumn.fromEntity(entity.status),
      application: Bip85ApplicationColumn.fromEntity(entity.application),
    );
  }

  Bip85DerivationEntity toEntity() {
    return Bip85DerivationEntity(
      path: path,
      xprvFingerprint: xprvFingerprint,
      alias: alias,
      status: status.toEntity(),
      application: application.toEntity(),
      index: index,
    );
  }
}
