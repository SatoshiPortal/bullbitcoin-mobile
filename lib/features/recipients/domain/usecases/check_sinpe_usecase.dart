import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';

class CheckSinpeParams {
  final String phoneNumber;

  CheckSinpeParams({required this.phoneNumber});
}

class CheckSinpeResult {
  final String ownerName;

  CheckSinpeResult({required this.ownerName});
}

class CheckSinpeUsecase {
  final RecipientsRepository _recipientsRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  CheckSinpeUsecase({
    required this._recipientsRepository,
    required this._getRecipientsEnvironmentUsecase,
  });

  @useResult
  Future<Result<CheckSinpeResult, RecipientsFailure>> execute(
    CheckSinpeParams params,
  ) async {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        return Err(failure);
    }

    return (await _recipientsRepository.checkSinpe(
      phoneNumber: params.phoneNumber,
      isTestnet: isTestnet,
    )).map((ownerName) => CheckSinpeResult(ownerName: ownerName));
  }
}
