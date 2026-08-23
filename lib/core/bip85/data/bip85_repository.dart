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
        error: e.runtimeType,
        trace: st,
      );
      return const Err(Bip85DerivationFailure('BIP85 hex derivation failed'));
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
        error: e.runtimeType,
        trace: st,
      );
      return const Err(
        Bip85DerivationFailure('BIP85 mnemonic derivation failed'),
      );
    }
  }

  @useResult
  Future<Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>
  deriveMnemonicPreview({
    required String xprvBase58,
    required bip39.MnemonicLength length,
    required int index,
  }) async {
    try {
      return Ok(
        _datasource.deriveMnemonicPreview(
          xprvBase58: xprvBase58,
          length: length,
          index: index,
        ),
      );
    } catch (error, trace) {
      log.severe(
        message: 'Bip85Repository.deriveMnemonicPreview failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(Bip85DerivationFailure('BIP85 mnemonic preview failed'));
    }
  }

  @useResult
  Future<Result<Bip85DerivationEntity?, Bip85Failure>> fetch(
    String path,
  ) async {
    try {
      return Ok((await _datasource.fetch(path))?.toEntity());
    } catch (error, trace) {
      log.severe(
        message: 'Bip85Repository.fetch failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(Bip85StorageFailure('BIP85 derivation lookup failed'));
    }
  }

  @useResult
  Future<Result<int, Bip85Failure>> fetchNextIndexForApplication(
    Bip85Application application, {
    Set<int> excludedIndices = const {},
  }) async {
    try {
      final applicationColumn = Bip85ApplicationColumn.fromEntity(application);
      final index = await _datasource.fetchNextIndexForApplication(
        applicationColumn,
        excludedIndices: excludedIndices,
      );
      return Ok(index);
    } catch (e, st) {
      log.severe(
        message: 'Bip85Repository.fetchNextIndexForApplication failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(Bip85StorageFailure('BIP85 index lookup failed'));
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
        error: e.runtimeType,
        trace: st,
      );
      return const Err(Bip85StorageFailure('BIP85 derivation listing failed'));
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
      log.severe(
        message: 'Bip85Repository.revoke failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(Bip85StorageFailure('BIP85 revocation failed'));
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
        error: e.runtimeType,
        trace: st,
      );
      return const Err(Bip85StorageFailure('BIP85 activation failed'));
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
      log.severe(
        message: 'Bip85Repository.alias failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(Bip85StorageFailure('BIP85 alias update failed'));
    }
  }
}
