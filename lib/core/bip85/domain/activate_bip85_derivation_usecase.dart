import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';

class ActivateBip85DerivationUsecase {
  final Bip85Repository _bip85Repository;

  ActivateBip85DerivationUsecase({required Bip85Repository bip85Repository})
    : _bip85Repository = bip85Repository;

  Future<void> execute(Bip85DerivationEntity derivation) async {
    try {
      await _bip85Repository.activate(derivation);
    } catch (e) {
      rethrow;
    }
  }
}
