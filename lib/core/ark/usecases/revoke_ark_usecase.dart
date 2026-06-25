import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class RevokeArkUsecase {
  final Bip85Repository _bip85Repository;

  RevokeArkUsecase({required this._bip85Repository});

  Future<void> execute() async {
    final List<Bip85DerivationEntity> derivations;
    switch (await _bip85Repository.fetchAll()) {
      case Err():
        return;
      case Ok(:final value):
        derivations = value;
    }

    for (final derivation in derivations) {
      if (derivation.application == Bip85Application.hex &&
          derivation.index == Ark.bip85Index) {
        switch (await _bip85Repository.revoke(derivation)) {
          case Ok():
            break;
          case Err(:final failure):
            log.warning(
              'RevokeArkUsecase: failed to revoke ark derivation: ${failure.logMessage}',
            );
        }
        break;
      }
    }
  }
}
