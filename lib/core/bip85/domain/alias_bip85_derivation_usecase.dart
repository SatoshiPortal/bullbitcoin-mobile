import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class AliasBip85DerivationUsecase {
  final Bip85Repository _bip85Repository;

  AliasBip85DerivationUsecase({required this._bip85Repository});

  @useResult
  Future<Result<void, Bip85Failure>> execute({
    required Bip85DerivationEntity derivation,
    required String alias,
  }) =>
      _bip85Repository.alias(derivation, alias);
}
