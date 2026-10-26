import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_repository.dart';

class FetchRecoverbullUrlUsecase {
  final RecoverBullRepository recoverBullRepository;

  FetchRecoverbullUrlUsecase({required this.recoverBullRepository});

  Future<Result<Uri, RecoverBullFailure>> execute() =>
      recoverBullRepository.fetchUrl();
}
