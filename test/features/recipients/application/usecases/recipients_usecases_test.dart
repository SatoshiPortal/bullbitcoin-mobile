import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGateway extends Mock implements RecipientsGatewayPort {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

RecipientDetails _details() => const RecipientDetailsDto(
  recipientType: RecipientType.sinpeMovilCrc,
  phoneNumber: '8888-8888',
).toDomain();

UserSummary _summaryWith(String? currency) => UserSummary(
  userNumber: 1,
  groups: const [],
  profile: const UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: const [],
  currency: currency,
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

void main() {
  late _MockGateway gateway;
  late _MockGetRecipientsEnvironmentUsecase environment;

  setUp(() {
    gateway = _MockGateway();
    environment = _MockGetRecipientsEnvironmentUsecase();
    when(
      () => environment.execute(),
    ).thenAnswer((_) async => const Ok(Environment.mainnet));
    registerFallbackValue(_details());
  });

  // The gateway is the boundary and has already mapped its failure. These
  // assert the use-cases forward it untouched rather than re-wrapping it,
  // which is exactly what produced the doubly-wrapped message the UI showed.
  group('use-cases forward the gateway failure untouched', () {
    test('GetRecipientsUsecase', () async {
      when(
        () => gateway.listRecipients(
          isTestnet: any(named: 'isTestnet'),
          fiatOnly: any(named: 'fiatOnly'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          recipientTypes: any(named: 'recipientTypes'),
          isOwner: any(named: 'isOwner'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => const Err(RecipientsLoadFailure()));

      final result = await GetRecipientsUsecase(
        recipientsGateway: gateway,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(GetRecipientsParams());

      switch (result) {
        case Ok():
          fail('a gateway failure must not be reported as recipients');
        case Err(:final failure):
          expect(failure, isA<RecipientsLoadFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('AddRecipientUsecase', () async {
      when(
        () => gateway.saveRecipient(any(), isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => const Err(RecipientsSaveFailure()));

      final result =
          await AddRecipientUsecase(
            recipientsGateway: gateway,
            getRecipientsEnvironmentUsecase: environment,
          ).execute(
            AddRecipientParams(
              recipientDetails: const RecipientDetailsDto(
                recipientType: RecipientType.sinpeMovilCrc,
                phoneNumber: '8888-8888',
              ),
            ),
          );

      expect(result, isA<Err<AddRecipientResult, RecipientsFailure>>());
    });

    test('CheckSinpeUsecase', () async {
      when(
        () => gateway.checkSinpe(
          phoneNumber: any(named: 'phoneNumber'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => const Err(RecipientsSinpeLookupFailure()));

      final result = await CheckSinpeUsecase(
        recipientsGateway: gateway,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(CheckSinpeParams(phoneNumber: '+50688887777'));

      switch (result) {
        case Ok():
          fail('a gateway failure must not be reported as an owner name');
        case Err(:final failure):
          expect(failure, isA<RecipientsSinpeLookupFailure>());
      }
    });

    test('ListCadBillersUsecase', () async {
      when(
        () => gateway.listCadBillers(
          searchTerm: any(named: 'searchTerm'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => const Err(RecipientsCadBillerSearchFailure()));

      final result = await ListCadBillersUsecase(
        recipientsGateway: gateway,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(ListCadBillersParams(searchTerm: 'hydro'));

      expect(result, isA<Err<ListCadBillersResult, RecipientsFailure>>());
    });
  });

  test(
    'a failed environment read is returned, not thrown: these use-cases '
    'promise a Result and the bloc has no catch left to stop a throw',
    () async {
      when(
        () => environment.execute(),
      ).thenAnswer((_) async => const Err(RecipientsUnexpectedFailure()));

      final result = await GetRecipientsUsecase(
        recipientsGateway: gateway,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(GetRecipientsParams());

      expect(result, isA<Err<GetRecipientsResult, RecipientsFailure>>());
      // The gateway is never reached without an environment to scope the call.
      verifyNever(
        () => gateway.listRecipients(isTestnet: any(named: 'isTestnet')),
      );
    },
  );

  test('a domain rejection is returned, not thrown: toDomain() raises for a '
      'missing or invalid field and nothing above would catch it', () async {
    // A SINPE recipient with no phone number. The form should have blocked
    // this, so reaching here means form and domain validation have drifted —
    // which is user-reachable, and used to hang the Continue button.
    final usecase = AddRecipientUsecase(
      recipientsGateway: gateway,
      getRecipientsEnvironmentUsecase: environment,
    );

    final result = await usecase.execute(
      AddRecipientParams(
        recipientDetails: const RecipientDetailsDto(
          recipientType: RecipientType.sinpeMovilCrc,
        ),
      ),
    );

    switch (result) {
      case Ok():
        fail('an invalid recipient must not be reported as saved');
      case Err(:final failure):
        expect(failure, isA<RecipientsSaveFailure>());
        expect(failure.logMessage, isNull);
    }
    // The gateway is never called with details the domain rejected.
    verifyNever(
      () => gateway.saveRecipient(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  group('GetRecipientsEnvironmentUsecase', () {
    test('maps a thrown settings read to a typed failure', () async {
      final settings = _MockSettingsRepository();
      when(() => settings.fetch()).thenThrow(Exception('drift: locked'));

      final result = await GetRecipientsEnvironmentUsecase(settings).execute();

      switch (result) {
        case Ok():
          fail('a thrown settings read must not be reported as an environment');
        case Err(:final failure):
          expect(failure, isA<RecipientsUnexpectedFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('returns the environment on success', () async {
      final settings = _MockSettingsRepository();
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );

      final result = await GetRecipientsEnvironmentUsecase(settings).execute();

      expect(
        (result as Ok<Environment, RecipientsFailure>).value,
        Environment.testnet,
      );
    });
  });

  group('GetPreferredJurisdictionUsecase', () {
    late _MockGetExchangeUserSummaryUsecase summary;

    setUp(() => summary = _MockGetExchangeUserSummaryUsecase());

    test('maps the account currency to a jurisdiction', () async {
      when(
        () => summary.execute(),
      ).thenAnswer((_) async => _summaryWith('CRC'));

      final result = await GetPreferredJurisdictionUsecase(summary).execute();

      expect((result as Ok<String, RecipientsFailure>).value, 'CR');
    });

    test('an unknown currency falls back rather than failing', () async {
      when(
        () => summary.execute(),
      ).thenAnswer((_) async => _summaryWith('JPY'));

      final result = await GetPreferredJurisdictionUsecase(summary).execute();

      expect(
        (result as Ok<String, RecipientsFailure>).value,
        GetPreferredJurisdictionUsecase.defaultJurisdiction,
      );
    });

    test('a thrown summary read becomes a typed failure instead of escaping '
        'into the bloc', () async {
      when(() => summary.execute()).thenThrow(Exception('401 unauthenticated'));

      final result = await GetPreferredJurisdictionUsecase(summary).execute();

      switch (result) {
        case Ok():
          fail('a thrown read must not be reported as a jurisdiction');
        case Err(:final failure):
          expect(failure, isA<RecipientsUnexpectedFailure>());
          expect(failure.logMessage, isNull);
      }
    });
  });
}
