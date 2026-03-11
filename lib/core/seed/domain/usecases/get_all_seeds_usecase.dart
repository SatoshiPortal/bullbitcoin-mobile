import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetAllSeedsUsecase {
  final SeedRepository _seedRepository;

  GetAllSeedsUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<List<MnemonicSeed>> execute() async {
    try {
      final seeds = await _seedRepository.getAllMnemonicSeeds();
      return seeds;
    } catch (e) {
      log.severe(
        message: 'Failed to fetch all seeds from secure storage',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }
}
