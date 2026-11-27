import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/add_recipient_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/check_sinpe_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/list_cad_billers_usecase.dart';
import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements RecipientsRepository {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSepaVirtualPayeeRepository extends Mock
    implements RecipientsRepository {}

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements _SummaryReader {}

abstract interface class _SummaryReader {
  Future<Result<UserSummary, ExchangeFailure>> execute();
}

RecipientDetails _details() => const RecipientDetailsInput(
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
  late _MockRepository repository;
  late _MockGetRecipientsEnvironmentUsecase environment;

  setUp(() {
    repository = _MockRepository();
    environment = _MockGetRecipientsEnvironmentUsecase();
    when(() => environment.execute())
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    registerFallbackValue(_details());
  });

  // The repository is the boundary and has already mapped its failure. These
  // assert the use-cases forward it untouched rather than re-wrapping it,
  // which is exactly what produced the doubly-wrapped message the UI showed.
  group('use-cases forward the repository failure untouched', () {
    test('GetRecipientsUsecase', () async {
      when(
        () => repository.listRecipients(
          isTestnet: any(named: 'isTestnet'),
          fiatOnly: any(named: 'fiatOnly'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          recipientTypes: any(named: 'recipientTypes'),
          isOwner: any(named: 'isOwner'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async => const Err(ExchangeRecipientsLoadFailure()));

      final result = await GetRecipientsUsecase(
        recipientsRepository: repository,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(GetRecipientsParams());

      switch (result) {
        case Ok():
          fail('a repository failure must not be reported as recipients');
        case Err(:final failure):
          expect(failure, isA<ExchangeRecipientsLoadFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('AddRecipientUsecase', () async {
      when(
        () =>
            repository.saveRecipient(any(), isTestnet: any(named: 'isTestnet')),
      ).thenAnswer((_) async => const Err(ExchangeRecipientsSaveFailure()));

      final result =
          await AddRecipientUsecase(
            recipientsRepository: repository,
            sepaVirtualPayeeRepository: _MockSepaVirtualPayeeRepository(),
            getRecipientsEnvironmentUsecase: environment,
          ).execute(
            AddRecipientParams(
              recipientDetails: const RecipientDetailsInput(
                recipientType: RecipientType.sinpeMovilCrc,
                phoneNumber: '8888-8888',
              ),
            ),
          );

      switch (result) {
        case Ok():
          fail(
            'a repository failure must not be reported as a saved recipient',
          );
        case Err(:final failure):
          expect(failure, isA<ExchangeRecipientsSaveFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('CheckSinpeUsecase', () async {
      when(
        () => repository.checkSinpe(
          phoneNumber: any(named: 'phoneNumber'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer(
        (_) async => const Err(ExchangeRecipientsSinpeLookupFailure()),
      );

      final result = await CheckSinpeUsecase(
        recipientsRepository: repository,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(CheckSinpeParams(phoneNumber: '+50688887777'));

      switch (result) {
        case Ok():
          fail('a repository failure must not be reported as an owner name');
        case Err(:final failure):
          expect(failure, isA<ExchangeRecipientsSinpeLookupFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('ListCadBillersUsecase', () async {
      when(
        () => repository.listCadBillers(
          searchTerm: any(named: 'searchTerm'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer(
        (_) async => const Err(ExchangeRecipientsCadBillerSearchFailure()),
      );

      final result = await ListCadBillersUsecase(
        recipientsRepository: repository,
        getRecipientsEnvironmentUsecase: environment,
      ).execute(ListCadBillersParams(searchTerm: 'hydro'));

      switch (result) {
        case Ok():
          fail('a repository failure must not be reported as a biller list');
        case Err(:final failure):
          expect(failure, isA<ExchangeRecipientsCadBillerSearchFailure>());
          expect(failure.logMessage, isNull);
      }
    });
  });

  test('a failed environment read is returned, not thrown: these use-cases '
      'promise a Result and the bloc has no catch left to stop a throw', () async {
    when(() => environment.execute())
        .thenAnswer((_) async => const Err(ExchangeUnexpectedFailure()));

    final result = await GetRecipientsUsecase(
      recipientsRepository: repository,
      getRecipientsEnvironmentUsecase: environment,
    ).execute(GetRecipientsParams());

    expect(result, isA<Err<GetRecipientsResult, ExchangeFailure>>());
    // The repository is never reached without an environment to scope the call.
    verifyNever(
      () => repository.listRecipients(isTestnet: any(named: 'isTestnet')),
    );
  });

  test('a domain rejection is returned, not thrown: toDomain() raises for a '
      'missing or invalid field and nothing above would catch it', () async {
    // A SINPE recipient with no phone number. The form should have blocked
    // this, so reaching here means form and domain validation have drifted —
    // which is user-reachable, and used to hang the Continue button.
    final usecase = AddRecipientUsecase(
      recipientsRepository: repository,
      sepaVirtualPayeeRepository: _MockSepaVirtualPayeeRepository(),
      getRecipientsEnvironmentUsecase: environment,
    );

    final result = await usecase.execute(
      AddRecipientParams(
        recipientDetails: const RecipientDetailsInput(
          recipientType: RecipientType.sinpeMovilCrc,
        ),
      ),
    );

    switch (result) {
      case Ok():
        fail('an invalid recipient must not be reported as saved');
      case Err(:final failure):
        expect(failure, isA<ExchangeRecipientsSaveFailure>());
        expect(failure.logMessage, isNull);
    }
    // The repository is never called with details the domain rejected.
    verifyNever(
      () => repository.saveRecipient(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  group('GetRecipientsEnvironmentUsecase', () {
    test('maps a thrown settings read to a typed failure', () async {
      final settings = _MockSettingsRepository();
      when(() => settings.fetch()).thenThrow(Exception('settings unavailable'));

      final result = await GetRecipientsEnvironmentUsecase(settings).execute();

      switch (result) {
        case Ok():
          fail('a thrown settings read must not be reported as an environment');
        case Err(:final failure):
          expect(failure, isA<ExchangeUnexpectedFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('returns the environment on success', () async {
      final settings = _MockSettingsRepository();
      when(() => settings.fetch()).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );

      final result = await GetRecipientsEnvironmentUsecase(settings).execute();

      expect(
        (result as Ok<Environment, ExchangeFailure>).value,
        Environment.testnet,
      );
    });
  });

  group('GetPreferredJurisdictionUsecase', () {
    late _MockGetExchangeUserSummaryUsecase summary;

    setUp(() => summary = _MockGetExchangeUserSummaryUsecase());

    test('maps the account currency to a jurisdiction', () async {
      when(() => summary.execute())
          .thenAnswer((_) async => Ok(_summaryWith('CRC')));

      final result = await GetPreferredJurisdictionUsecase(
        exchangeForTesting(getUserSummary: (_) => summary.execute()),
      ).execute();

      expect(
        (result as Ok<Jurisdiction?, ExchangeFailure>).value,
        Jurisdiction.costaRica,
      );
    });

    test('USD maps to Costa Rica, where its rails are', () async {
      when(() => summary.execute())
          .thenAnswer((_) async => Ok(_summaryWith('USD')));

      final result = await GetPreferredJurisdictionUsecase(
        exchangeForTesting(getUserSummary: (_) => summary.execute()),
      ).execute();

      expect(
        (result as Ok<Jurisdiction?, ExchangeFailure>).value,
        Jurisdiction.costaRica,
      );
    });

    test(
      'an unknown currency gives no preference rather than Canada',
      () async {
        when(() => summary.execute())
            .thenAnswer((_) async => Ok(_summaryWith('JPY')));

        final result = await GetPreferredJurisdictionUsecase(
          exchangeForTesting(getUserSummary: (_) => summary.execute()),
        ).execute();

        expect((result as Ok<Jurisdiction?, ExchangeFailure>).value, isNull);
      },
    );

    test('a refused summary read becomes a typed failure instead of escaping '
        'into the bloc', () async {
      when(
        () => summary.execute(),
      ).thenAnswer((_) async => const Err(ExchangeAccountUnavailableFailure()));

      final result = await GetPreferredJurisdictionUsecase(
        exchangeForTesting(getUserSummary: (_) => summary.execute()),
      ).execute();

      switch (result) {
        case Ok():
          fail('a failed read must not be reported as a jurisdiction');
        case Err(:final failure):
          expect(failure, isA<ExchangeUnexpectedFailure>());
          expect(failure.logMessage, isNull);
      }
    });
  });
}
