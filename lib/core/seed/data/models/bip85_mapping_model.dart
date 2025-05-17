import 'package:bb_mobile/core/seed/domain/entity/bip85_application.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bip85_mapping_model.freezed.dart';

@freezed
sealed class Bip85MappingModel with _$Bip85MappingModel {
  const factory Bip85MappingModel({
    required String seedFingerprint,
    required String masterSeedFingerprint,
    required String bip85DerivationPath,
  }) = _Bip85MappingModel;
  const Bip85MappingModel._();

  factory Bip85MappingModel.fromTableRow(Bip85MappingRow row) {
    return Bip85MappingModel(
      seedFingerprint: row.seedFingerprint,
      masterSeedFingerprint: row.masterSeedFingerprint,
      bip85DerivationPath: row.bip85DerivationPath,
    );
  }

  Bip85MappingRow toTableRow() {
    return Bip85MappingRow(
      seedFingerprint: seedFingerprint,
      masterSeedFingerprint: masterSeedFingerprint,
      bip85DerivationPath: bip85DerivationPath,
    );
  }

  Bip85Application get bip85Application {
    final pathParts = bip85DerivationPath.split('/');
    final m = pathParts[0];
    final bip85 = pathParts[1];

    if (m != 'm' || bip85 != "83696968'") {
      throw Exception('Invalid BIP85 derivation path: $bip85DerivationPath');
    }

    final application = pathParts[2];
    return Bip85Application.values.firstWhere(
      (app) => app.derivationPathValue == application,
    );
  }

  int get accountIndex {
    final pathParts = bip85DerivationPath.split('/');
    final application = bip85Application;

    String indexPart;
    switch (application) {
      case Bip85Application.bip39:
        indexPart = pathParts[5];
    }

    return int.parse(indexPart.replaceAll("'", ""));
  }
}
