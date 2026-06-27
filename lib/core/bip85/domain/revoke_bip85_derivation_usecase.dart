import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class RevokeBip85DerivationUsecase {
  final Bip85Repository _bip85Repository;

  RevokeBip85DerivationUsecase({required this._bip85Repository});

  @useResult
  Future<Result<void, Bip85Failure>> execute(
    Bip85DerivationEntity derivation,
  ) =>
      _bip85Repository.revoke(derivation);
}
