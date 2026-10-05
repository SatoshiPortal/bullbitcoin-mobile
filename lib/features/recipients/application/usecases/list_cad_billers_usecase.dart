import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/recipients/application/dtos/cad_biller_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class ListCadBillersParams {
  final String searchTerm;

  ListCadBillersParams({required this.searchTerm});
}

class ListCadBillersResult {
  final List<CadBillerDto> billers;

  ListCadBillersResult({required this.billers});
}

class ListCadBillersUsecase {
  final RecipientsGatewayPort _recipientsGateway;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  ListCadBillersUsecase({
    required this._recipientsGateway,
    required this._getRecipientsEnvironmentUsecase,
  });

  @useResult
  Future<Result<ListCadBillersResult, RecipientsFailure>> execute(
    ListCadBillersParams params,
  ) async {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        return Err(failure);
    }

    return (await _recipientsGateway.listCadBillers(
      searchTerm: params.searchTerm,
      isTestnet: isTestnet,
    )).map(
      (billers) => ListCadBillersResult(
        billers: billers.map((e) => CadBillerDto.fromDomain(e)).toList(),
      ),
    );
  }
}
