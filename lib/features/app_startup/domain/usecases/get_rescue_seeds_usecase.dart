import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetRescueSeedsUsecase {
  final SeedRepository _seedRepository;

  GetRescueSeedsUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<List<MnemonicSeed>> execute() async {
    try {
      final seeds = await _seedRepository.getAllMnemonicSeeds();
      log.fine('Retrieved ${seeds.length} rescue seeds');
      return seeds;
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to retrieve rescue seeds',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }
}
