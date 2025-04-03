import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

class GetLiquidFeesUsecase {
  final FeesRepository _feesRepository;

  GetLiquidFeesUsecase({
    required FeesRepository feesRepository,
  }) : _feesRepository = feesRepository;

  Future<FeeOptions> execute({
    required bool isTestnet,
  }) async {
    // Get the fee options for the Liquid network
    return await _feesRepository.getLiquidNetworkFees(
      isTestnet: isTestnet,
    );
  }
}
