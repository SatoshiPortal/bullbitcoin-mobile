import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
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
  // TODO: The settings repository should not be used directly here, since it is
  // from another domain. We should use a settings port that gets the settings
  // facade injected so no business logic is skipped from the settings domain.
  final SettingsRepository _settingsRepository;

  ListCadBillersUsecase({
    required RecipientsGatewayPort recipientsGateway,
    required SettingsRepository settingsRepository,
  }) : _recipientsGateway = recipientsGateway,
       _settingsRepository = settingsRepository;

  Future<ListCadBillersResult> execute(ListCadBillersParams params) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final billers = await _recipientsGateway.listCadBillers(
      searchTerm: params.searchTerm,
      isTestnet: isTestnet,
    );

    return ListCadBillersResult(
      billers: billers.map((e) => CadBillerDto.fromDomain(e)).toList(),
    );
  }
}
