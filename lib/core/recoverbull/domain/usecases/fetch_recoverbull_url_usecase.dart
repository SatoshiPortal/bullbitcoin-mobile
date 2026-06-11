import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class FetchRecoverbullUrlUsecase {
  final RecoverBullRepository _recoverBullRepository;

  FetchRecoverbullUrlUsecase({
    required this._recoverBullRepository,
  });

  Future<Uri> execute() async {
    return await _recoverBullRepository.fetchUrl();
  }
}
