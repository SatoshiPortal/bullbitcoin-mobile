import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:meta/meta.dart';

/// Composes the core entropy reader with the first-party reservation policy.
class FetchUnreservedBip85DerivationsWithEntropyUsecase {
  final FetchAllBip85DerivationsWithEntropyUsecase _fetchAll;
  final Bip85RegistryFacade _registry;

  const FetchUnreservedBip85DerivationsWithEntropyUsecase({
    required this._fetchAll,
    required this._registry,
  });

  @useResult
  Future<
    Result<
      List<({Bip85DerivationEntity derivation, String entropy})>,
      Bip85Failure
    >
  >
  execute() {
    return _fetchAll.execute(excludedPaths: _registry.reservedWalletSeedPaths);
  }
}
