import 'package:bb_mobile/features/bip85_entropy/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/errors/bip85_failure.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';

class Bip85Repository {
  final SecretsInventory _inventory;

  Bip85Repository({required this._inventory});

  @useResult
  Future<Result<RecordedDerivation, Bip85Failure>> reserveHex({
    required Fingerprint parent,
    required int length,
    String? alias,
  }) async => (await _inventory.reserveHexDerivation(
    parent: parent,
    length: length,
    alias: alias,
  )).mapErr((_) => const Bip85StorageFailure());

  @useResult
  Future<Result<RecordedDerivation, Bip85Failure>> reserveMnemonic({
    required Fingerprint parent,
    required bip39.MnemonicLength length,
    required bip39.Language language,
    String? alias,
  }) async => (await _inventory.reserveMnemonicDerivation(
    parent: parent,
    length: length,
    language: language,
    alias: alias,
  )).mapErr((_) => const Bip85StorageFailure());

  @useResult
  Future<Result<List<Bip85DerivationEntity>, Bip85Failure>> fetchAll() async {
    switch (await _inventory.listDerivations()) {
      case Err():
        return const Err(Bip85StorageFailure());
      case Ok(:final value):
        final result = <Bip85DerivationEntity>[];
        for (final row in value) {
          final index = row.index;
          final application = Bip85Application.values
              .where((value) => value.name == row.application)
              .firstOrNull;
          final status = Bip85Status.values
              .where((value) => value.name == row.status)
              .firstOrNull;
          if (index == null || application == null || status == null) {
            return const Err(Bip85StorageFailure('Unreadable derivation'));
          }
          result.add(
            Bip85DerivationEntity(
              path: row.path,
              xprvFingerprint: row.parentFingerprint,
              alias: row.alias,
              status: status,
              application: application,
              index: index,
            ),
          );
        }
        return Ok(result);
    }
  }

  @useResult
  Future<Result<void, Bip85Failure>> revoke(Bip85DerivationEntity derivation) =>
      _setActive(derivation, false);

  @useResult
  Future<Result<void, Bip85Failure>> activate(
    Bip85DerivationEntity derivation,
  ) => _setActive(derivation, true);

  Future<Result<void, Bip85Failure>> _setActive(
    Bip85DerivationEntity derivation,
    bool active,
  ) async => (await _inventory.setDerivationActive(
    _record(derivation),
    active: active,
  )).mapErr((_) => const Bip85StorageFailure());

  @useResult
  Future<Result<void, Bip85Failure>> alias(
    Bip85DerivationEntity derivation,
    String alias,
  ) async => (await _inventory.renameDerivation(
    _record(derivation),
    alias,
  )).mapErr((_) => const Bip85StorageFailure());

  RecordedDerivation _record(Bip85DerivationEntity value) => RecordedDerivation(
    path: value.path,
    parentFingerprint: value.xprvFingerprint,
    application: value.application.name,
    status: value.status.name,
    alias: value.alias,
  );
}
