import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/recipients/domain/entities/cad_biller_summary.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';

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
