import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/data/interac_security_details_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsGateway extends Mock implements RecipientsGatewayPort {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockRecipientsGateway recipientsGateway;
  late _MockSettingsRepository settingsRepository;
  late InteracSecurityDetailsRepositoryImpl repository;
  late InteracSecurityDetails details;

  setUp(() {
    recipientsGateway = _MockRecipientsGateway();
    settingsRepository = _MockSettingsRepository();
    repository = InteracSecurityDetailsRepositoryImpl(
      recipientsGateway,
      settingsRepository,
    );
    details =
        (InteracSecurityDetails.create(
                  recipientId: 'recipient-1',
                  email: 'person@example.com',
                  securityQuestion: 'Favourite city?',
                  securityAnswer: 'Montreal',
                )
                as Ok<InteracSecurityDetails, RecipientsFailure>)
            .value;
  });

  test('updates security details on mainnet', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => recipientsGateway.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async {});

    final result = await repository.update(details);

    expect(result, isA<Ok<void, RecipientsFailure>>());
    verify(
      () => recipientsGateway.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
        isTestnet: false,
      ),
    ).called(1);
  });

  test('routes updates to testnet', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => recipientsGateway.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async {});

    await repository.update(details);

    verify(
      () => recipientsGateway.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
        isTestnet: true,
      ),
    ).called(1);
  });

  test('maps gateway exceptions to a sanitized failure', () async {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => recipientsGateway.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenThrow(Exception('Montreal'));

    final result = await repository.update(details);

    expect(result, isA<Err<void, RecipientsFailure>>());
    final failure = (result as Err<void, RecipientsFailure>).failure;
    expect(failure.logMessage, isNot(contains('Montreal')));
  });
}
