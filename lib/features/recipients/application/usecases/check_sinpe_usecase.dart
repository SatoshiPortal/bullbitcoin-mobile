import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class CheckSinpeParams {
  final String phoneNumber;

  CheckSinpeParams({required this.phoneNumber});
}

class CheckSinpeResult {
  final String ownerName;

  CheckSinpeResult({required this.ownerName});
}

class CheckSinpeUsecase {
  final RecipientsGatewayPort _recipientsGateway;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  CheckSinpeUsecase({
    required this._recipientsGateway,
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

    return (await _recipientsGateway.checkSinpe(
      phoneNumber: params.phoneNumber,
      isTestnet: isTestnet,
    )).map((ownerName) => CheckSinpeResult(ownerName: ownerName));
  }
}
