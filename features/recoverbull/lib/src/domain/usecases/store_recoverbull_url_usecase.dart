import '../repositories/recoverbull_repository.dart';

class StoreRecoverbullUrlUsecase {
  final RecoverBullRepository recoverBullRepository;

  StoreRecoverbullUrlUsecase({required this.recoverBullRepository});

  Future<void> execute(Uri url) async {
    await recoverBullRepository.storeUrl(url);
  }
}
