import 'package:bb_mobile/core_deprecated/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';

class GetAllSeedsUsecase {
  final SeedRepository _seedRepository;

  GetAllSeedsUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<List<MnemonicSeed>> execute() async {
    try {
      final seeds = await _seedRepository.getAllMnemonicSeeds();
      return seeds;
    } catch (e) {
      log.severe('Failed to fetch all seeds from secure storage: $e');
      rethrow;
    }
  }
}
