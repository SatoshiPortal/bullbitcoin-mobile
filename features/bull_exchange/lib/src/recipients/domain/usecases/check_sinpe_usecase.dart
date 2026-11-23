import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

class CheckSinpeParams {
  final String phoneNumber;

  CheckSinpeParams({required this.phoneNumber});
}

class CheckSinpeResult {
  final String ownerName;

  CheckSinpeResult({required this.ownerName});
}

class CheckSinpeUsecase {
  final ExchangeRecipients _recipientsRepository;
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
        isTestnet = value.requireHistoricalTestnet();
      case Err(:final failure):
        return Err(failure);
    }

    return (await _recipientsRepository.checkSinpe(
      phoneNumber: params.phoneNumber,
      isTestnet: isTestnet,
    )).map((ownerName) => CheckSinpeResult(ownerName: ownerName));
  }
}
