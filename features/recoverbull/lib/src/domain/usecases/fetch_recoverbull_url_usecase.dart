import '../repositories/recoverbull_repository.dart';

class FetchRecoverbullUrlUsecase {
  final RecoverBullRepository recoverBullRepository;

  FetchRecoverbullUrlUsecase({required this.recoverBullRepository});

  Future<Uri> execute() async {
    return await recoverBullRepository.fetchUrl();
  }
}
