import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class GetAllSeedsUsecase {
  final SeedRepository _seedRepository;

  const GetAllSeedsUsecase({required this._seedRepository});

  @useResult
  Future<Result<List<MnemonicSeed>, SeedFetchFailure>> execute() =>
      _seedRepository.getAllMnemonicSeeds();
}
