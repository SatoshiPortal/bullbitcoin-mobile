import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';

class FetchAllBip85DerivationsUsecase {
  final Bip85Repository _bip85Repository;

  FetchAllBip85DerivationsUsecase({required this._bip85Repository});

  Future<List<Bip85DerivationEntity>> execute() async {
    try {
      return await _bip85Repository.fetchAll();
    } catch (e) {
      rethrow;
    }
  }
}
