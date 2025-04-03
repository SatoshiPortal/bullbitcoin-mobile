import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';

class GetBitcoinFeesUsecase {
  final FeesRepository _feesRepository;

  GetBitcoinFeesUsecase({
    required FeesRepository feesRepository,
  }) : _feesRepository = feesRepository;

  Future<FeeOptions> execute({
    required bool isTestnet,
  }) async {
    // Get the fee options for the Bitcoin network
    return await _feesRepository.getBitcoinNetworkFees(
      isTestnet: isTestnet,
    );
  }
}
