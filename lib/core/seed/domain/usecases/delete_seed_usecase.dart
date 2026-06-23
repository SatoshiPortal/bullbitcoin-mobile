import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class DeleteSeedUsecase {
  final SeedRepository _seedRepository;

  const DeleteSeedUsecase({required this._seedRepository});

  @useResult
  Future<Result<void, SeedDeleteFailure>> execute(String fingerprint) =>
      _seedRepository.delete(fingerprint);
}
