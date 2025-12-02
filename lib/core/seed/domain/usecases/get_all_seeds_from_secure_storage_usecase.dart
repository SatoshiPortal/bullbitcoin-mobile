import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class GetAllSeedsFromSecureStorageUsecase {
  final SeedRepository _seedRepository;

  GetAllSeedsFromSecureStorageUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  /// Fetches all mnemonic seeds from secure storage
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
