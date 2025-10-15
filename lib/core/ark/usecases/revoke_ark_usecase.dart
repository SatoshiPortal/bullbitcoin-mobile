import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';

class RevokeArkUsecase {
  final Bip85Repository _bip85Repository;

  RevokeArkUsecase({required Bip85Repository bip85Repository})
    : _bip85Repository = bip85Repository;

  Future<void> execute() async {
    try {
      final derivations = await _bip85Repository.fetchAll();

      for (final derivation in derivations) {
        if (derivation.application == Bip85Application.hex &&
            derivation.index == Ark.bip85Index) {
          await _bip85Repository.revoke(derivation.path);
          break;
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
