import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bull_logger/bull_logger.dart';

final class InteracSecurityDetailsRepositoryImpl
    implements InteracSecurityDetailsRepository {
  final RecipientsRepository _recipientsRepository;
  final SettingsRepository _settingsRepository;

  const InteracSecurityDetailsRepositoryImpl(
    this._recipientsRepository,
    this._settingsRepository,
  );

  @override
  Future<Result<void, RecipientsFailure>> update(
    InteracSecurityDetails details,
  ) async {
    // The shared settings repository still throws, so this is the boundary
    // for it. The repository call below already returns a Result.
    final bool isTestnet;
    try {
      isTestnet = (await _settingsRepository.fetch()).environment.isTestnet;
    } on Object catch (e, st) {
      log.warning('Could not read the environment', error: e, trace: st);
      return const Err(RecipientsUnexpectedFailure());
    }

    return _recipientsRepository.updateInteracSecurityDetails(
      recipientId: details.recipientId,
      email: details.email,
      securityQuestion: details.securityQuestion,
      securityAnswer: details.securityAnswer,
      isTestnet: isTestnet,
    );
  }
}
