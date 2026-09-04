import '../repositories/recoverbull_repository.dart';

class StoreRecoverbullUrlUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreRecoverbullUrlUsecase({required this._recoverBullRepository});

  Future<void> execute(Uri url) async {
    await _recoverBullRepository.storeUrl(url);
  }
}
