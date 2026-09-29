import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bull_logger/bull_logger.dart';

final class InteracSecurityDetailsRepositoryImpl
    implements InteracSecurityDetailsRepository {
  const InteracSecurityDetailsRepositoryImpl(
    this._recipientsGateway,
    this._settingsRepository,
  );

  final RecipientsGatewayPort _recipientsGateway;
  final SettingsRepository _settingsRepository;

  @override
  Future<Result<void, RecipientsFailure>> update(
    InteracSecurityDetails details,
  ) async {
    try {
      final settings = await _settingsRepository.fetch();
      await _recipientsGateway.updateInteracSecurityDetails(
        recipientId: details.recipientId,
        email: details.email,
        securityQuestion: details.securityQuestion,
        securityAnswer: details.securityAnswer,
        isTestnet: settings.environment.isTestnet,
      );
      return const Ok(null);
    } catch (_) {
      const message = 'Failed to update Interac recipient security details';
      log.warning(message);
      return const Err(RecipientsUnexpectedFailure(message));
    }
  }
}
