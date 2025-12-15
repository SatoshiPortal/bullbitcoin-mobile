import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
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
  // TODO: The settings repository should not be used directly here, since it is
  // from another domain. We should use a settings port that gets the settings
  // facade injected so no business logic is skipped from the settings domain.
  final SettingsRepository _settingsRepository;

  CheckSinpeUsecase({
    required RecipientsGatewayPort recipientsGateway,
    required SettingsRepository settingsRepository,
  }) : _recipientsGateway = recipientsGateway,
       _settingsRepository = settingsRepository;

  Future<CheckSinpeResult> execute(CheckSinpeParams params) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final ownerName = await _recipientsGateway.checkSinpe(
      phoneNumber: params.phoneNumber,
      isTestnet: isTestnet,
    );

    return CheckSinpeResult(ownerName: ownerName);
  }
}
