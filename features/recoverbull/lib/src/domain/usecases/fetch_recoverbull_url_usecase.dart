import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';

class FetchRecoverbullUrlUsecase {
  final RecoverBullRepository _recoverBullRepository;

  FetchRecoverbullUrlUsecase({required this._recoverBullRepository});

  Future<Uri> execute() async {
    return await _recoverBullRepository.fetchUrl();
  }
}
