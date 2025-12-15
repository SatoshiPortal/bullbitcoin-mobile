import 'package:bb_mobile/core_deprecated/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core_deprecated/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/infra/database/tables/bip85_derivations_table.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class Bip85Repository {
  final Bip85Datasource _datasource;

  Bip85Repository({required Bip85Datasource datasource})
    : _datasource = datasource;

  Future<({String derivation, String hex})> deriveHex({
    required String xprvBase58,
    required int length,
    required int index,
    String? alias,
  }) async {
    try {
      final result = await _datasource.deriveHex(
        xprvBase58: xprvBase58,
        length: length,
        index: index,
        alias: alias,
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<({String derivation, bip39.Mnemonic mnemonic})> deriveMnemonic({
    required String xprvBase58,
    required bip39.MnemonicLength length,
    required int index,
    String? alias,
  }) async {
    try {
      final result = await _datasource.deriveMnemonic(
        xprvBase58: xprvBase58,
        length: length,
        index: index,
        alias: alias,
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> fetchNextIndexForApplication(Bip85Application application) async {
    try {
      final applicationColumn = Bip85ApplicationColumn.fromEntity(application);
      return await _datasource.fetchNextIndexForApplication(applicationColumn);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Bip85DerivationEntity>> fetchAll() async {
    try {
      final result = await _datasource.fetchAll();
      return result.map((e) => e.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> revoke(String path) async {
    try {
      await _datasource.revoke(path);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reactivate(String path) async {
    try {
      await _datasource.reactivate(path);
    } catch (e) {
      rethrow;
    }
  }
}
