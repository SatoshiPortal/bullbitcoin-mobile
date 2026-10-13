import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_repository.dart';

class StoreRecoverbullUrlUsecase {
  final RecoverBullRepository recoverBullRepository;

  StoreRecoverbullUrlUsecase({required this.recoverBullRepository});

  Future<Result<Null, RecoverBullFailure>> execute(Uri url) =>
      recoverBullRepository.storeUrl(url);
}
