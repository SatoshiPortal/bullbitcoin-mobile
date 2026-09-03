import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

class EnsureCanonicalSeedUsecase {
  final SeedRepository _seedRepository;

  const EnsureCanonicalSeedUsecase(this._seedRepository);

  Future<String> execute(Seed seed) =>
      _seedRepository.ensureCanonicalSeed(seed);
}
