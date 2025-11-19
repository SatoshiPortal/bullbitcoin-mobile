import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class StoreRecoverbullUrlUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreRecoverbullUrlUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute(Uri url) async {
    await _recoverBullRepository.storeUrl(url);
  }
}
