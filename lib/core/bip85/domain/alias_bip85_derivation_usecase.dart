import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';

class AliasBip85DerivationUsecase {
  final Bip85Repository _bip85Repository;

  AliasBip85DerivationUsecase({required Bip85Repository bip85Repository})
    : _bip85Repository = bip85Repository;

  Future<void> execute({
    required Bip85DerivationEntity derivation,
    required String alias,
  }) async {
    await _bip85Repository.alias(derivation, alias);
  }
}
