import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/recoverbull_repository.dart';

class FetchRecoverbullUrlUsecase {
  final RecoverBullRepository _recoverBullRepository;

  FetchRecoverbullUrlUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<Uri> execute() async {
    return await _recoverBullRepository.fetchUrl();
  }
}
