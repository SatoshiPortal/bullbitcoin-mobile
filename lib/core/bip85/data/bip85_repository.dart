import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class Bip85Repository {
  final Bip85Datasource _datasource;

  Bip85Repository({required this._datasource});

  @useResult
  Future<Result<({String derivation, String hex}), Bip85Failure>> deriveHex({
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
      return Ok(result);
    } catch (e, st) {
      log.severe(
        message: 'Bip85Repository.deriveHex failed',
        error: e,
        trace: st,
      );
      return Err(Bip85DerivationFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>
  deriveMnemonic({
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
      return Ok(result);
    } catch (e, st) {
      log.severe(
        message: 'Bip85Repository.deriveMnemonic failed',
        error: e,
        trace: st,
      );
      return Err(Bip85DerivationFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<int, Bip85Failure>> fetchNextIndexForApplication(
    Bip85Application application,
  ) async {
    try {
      final applicationColumn = Bip85ApplicationColumn.fromEntity(application);
      final index = await _datasource.fetchNextIndexForApplication(
        applicationColumn,
      );
      return Ok(index);
    } catch (e, st) {
      log.severe(
        message: 'Bip85Repository.fetchNextIndexForApplication failed',
        error: e,
        trace: st,
      );
      return Err(Bip85StorageFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<List<Bip85DerivationEntity>, Bip85Failure>> fetchAll() async {
    try {
      final result = await _datasource.fetchAll();
      return Ok(result.map((e) => e.toEntity()).toList());
    } catch (e, st) {
      log.severe(
        message: 'Bip85Repository.fetchAll failed',
        error: e,
        trace: st,
      );
      return Err(Bip85StorageFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<void, Bip85Failure>> revoke(
    Bip85DerivationEntity derivation,
  ) async {
    try {
      await _datasource.revoke(derivation.path);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'Bip85Repository.revoke failed', error: e, trace: st);
      return Err(Bip85StorageFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<void, Bip85Failure>> activate(
    Bip85DerivationEntity derivation,
  ) async {
    try {
      await _datasource.activate(derivation.path);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Bip85Repository.activate failed',
        error: e,
        trace: st,
      );
      return Err(Bip85StorageFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<void, Bip85Failure>> alias(
    Bip85DerivationEntity derivation,
    String alias,
  ) async {
    try {
      await _datasource.alias(derivation.path, alias);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'Bip85Repository.alias failed', error: e, trace: st);
      return Err(Bip85StorageFailure(e.toString()));
    }
  }
}
