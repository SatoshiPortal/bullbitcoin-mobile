import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class DeleteSeedUsecase {
  final SeedRepository _seedRepository;

  DeleteSeedUsecase({required SeedRepository seedRepository})
    : _seedRepository = seedRepository;

  Future<void> execute(String fingerprint) async {
    try {
      await _seedRepository.delete(fingerprint);
      log.fine('Deleted seed with fingerprint: $fingerprint');
    } catch (e) {
      log.severe('Failed to delete seed with fingerprint $fingerprint: $e');
      rethrow;
    }
  }
}
