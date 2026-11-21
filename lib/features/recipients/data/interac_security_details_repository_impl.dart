import 'package:primitives/primitives.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bull_logger/bull_logger.dart';

final class InteracSecurityDetailsRepositoryImpl
    implements InteracSecurityDetailsRepository {
  final RecipientsRepository _recipientsRepository;
  final Preferences _settingsRepository;

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
      final environment = ((await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment;
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(environment.name),
        NetworkCapability.exchange,
      )) {
        return const Err(RecipientsUnsupportedNetworkFailure());
      }
      isTestnet = environment.requireHistoricalTestnet();
    } on Exception catch (e, st) {
      log.warning(
        'Could not read the environment',
        error: e.runtimeType,
        trace: st,
      );
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
