import 'package:bb_mobile/core/bip85_derivations/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';

class Bip85DerivationModel {
  final String derivation;
  final String xprvFingerprint;
  final String? alias;
  final Bip85StatusColumn status;
  final Bip85ApplicationColumn application;

  Bip85DerivationModel({
    required this.derivation,
    required this.xprvFingerprint,
    required this.alias,
    required this.status,
    required this.application,
  });

  int get index {
    // Future applications may format the index differently.
    switch (application) {
      default:
        final lastPart = derivation.split('/').last;
        final index = int.parse(lastPart.replaceAll("'", ''));
        return index;
    }
  }

  factory Bip85DerivationModel.fromSqlite(Bip85DerivationRow row) {
    return Bip85DerivationModel(
      derivation: row.derivation,
      xprvFingerprint: row.xprvFingerprint,
      alias: row.alias,
      status: row.status,
      application: row.application,
    );
  }

  factory Bip85DerivationModel.fromEntity(Bip85DerivationEntity entity) {
    return Bip85DerivationModel(
      derivation: entity.derivation,
      xprvFingerprint: entity.xprvFingerprint,
      alias: entity.alias,
      status: Bip85StatusColumn.fromEntity(entity.status),
      application: Bip85ApplicationColumn.fromEntity(entity.application),
    );
  }

  Bip85DerivationEntity toEntity() {
    return Bip85DerivationEntity(
      derivation: derivation,
      xprvFingerprint: xprvFingerprint,
      alias: alias,
      status: status.toEntity(),
      application: application.toEntity(),
    );
  }
}
