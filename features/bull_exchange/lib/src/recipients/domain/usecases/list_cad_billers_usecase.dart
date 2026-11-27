import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:bull_exchange/src/recipients/domain/entities/cad_biller_summary.dart';

class ListCadBillersParams {
  final String searchTerm;

  ListCadBillersParams({required this.searchTerm});
}

class ListCadBillersResult {
  final List<CadBillerSummary> billers;

  ListCadBillersResult({required this.billers});
}

class ListCadBillersUsecase {
  final RecipientsRepository _recipientsRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  ListCadBillersUsecase({
    required this._recipientsRepository,
    required this._getRecipientsEnvironmentUsecase,
  });

  @useResult
  Future<Result<ListCadBillersResult, ExchangeFailure>> execute(
    ListCadBillersParams params,
  ) async {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.requireHistoricalTestnet();
      case Err(:final failure):
        return Err(failure);
    }

    return (await _recipientsRepository.listCadBillers(
      searchTerm: params.searchTerm,
      isTestnet: isTestnet,
    )).map(
      (billers) => ListCadBillersResult(
        billers: billers.map((e) => CadBillerSummary.fromDomain(e)).toList(),
      ),
    );
  }
}
