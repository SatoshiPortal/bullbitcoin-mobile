import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class GetNetworkFeesUsecase {
  final FeesRepository _feesRepository;

  GetNetworkFeesUsecase({
    required FeesRepository feesRepository,
  }) : _feesRepository = feesRepository;

  Future<FeeOptions> execute({
    required Network network,
  }) async {
    return await _feesRepository.getNetworkFees(
      network: network,
    );
  }
}
