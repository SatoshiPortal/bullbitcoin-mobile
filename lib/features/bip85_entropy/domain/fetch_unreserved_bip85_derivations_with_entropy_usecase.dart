import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class FetchUnreservedBip85DerivationsWithEntropyUsecase {
  final FetchAllBip85DerivationsWithEntropyUsecase _fetchAll;

  const FetchUnreservedBip85DerivationsWithEntropyUsecase(this._fetchAll);

  @useResult
  Future<
    Result<
      List<({Bip85DerivationEntity derivation, String entropy})>,
      Bip85Failure
    >
  >
  execute() => _fetchAll.execute(
    excludedPaths: Bip85Reservations.reservedPaths,
    excludedPathPrefixes: Bip85Reservations.reservedPathPrefixes,
  );
}
