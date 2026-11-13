import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/manage_exchange_access_usecase.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Access extends Mock implements ExchangeAccessFacade {}

class _Exchange extends Mock implements ExchangeFacade {}

void main() {
  late _Access access;
  late _Exchange exchange;
  late SetSettingsExchangeAccessUsecase usecase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    access = _Access();
    exchange = _Exchange();
    usecase = SetSettingsExchangeAccessUsecase(access, exchange);
  });

  test(
    'ON returns authenticationRequired without losing pending choice',
    () async {
      final wizard = WizardRepositoryImpl(WizardLocalDatasourceImpl());
      await wizard.savePending(
        const WizardChoices(
          exchangeAccess: true,
          touched: {WizardField.exchangeAccess},
        ),
      );
      when(access.beginActivation).thenAnswer(
        (_) async => const Ok(ExchangeAccessOutcome.authenticationRequired),
      );
      final result = await usecase.execute(true);
      expect(
        result,
        isA<Ok<ExchangeAccessOutcome, SettingsFailure>>().having(
          (value) => value.value,
          'outcome',
          ExchangeAccessOutcome.authenticationRequired,
        ),
      );
      expect(
        (await wizard.readPending())?.touched,
        contains(WizardField.exchangeAccess),
      );
      verifyNever(exchange.logout);
    },
  );

  test(
    'OFF success clears pending exchange while keeping other choices',
    () async {
      final wizard = WizardRepositoryImpl(WizardLocalDatasourceImpl());
      await wizard.savePending(
        const WizardChoices(
          language: Language.franceFrench,
          exchangeAccess: true,
          touched: {WizardField.language, WizardField.exchangeAccess},
        ),
      );
      when(exchange.logout).thenAnswer((_) async => const Ok(null));
      final result = await usecase.execute(false);
      expect(
        result,
        isA<Ok<ExchangeAccessOutcome, SettingsFailure>>().having(
          (value) => value.value,
          'outcome',
          ExchangeAccessOutcome.applied,
        ),
      );
      expect((await wizard.readPending())?.touched, {WizardField.language});
      expect((await wizard.readPending())?.language, Language.franceFrench);
      verify(exchange.logout).called(1);
    },
  );

  test('OFF cleanup failure returns a settings failure', () async {
    when(
      exchange.logout,
    ).thenAnswer((_) async => const Err(ExchangeSessionClearFailure()));
    final result = await usecase.execute(false);
    expect(
      result,
      isA<Err<ExchangeAccessOutcome, SettingsFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<SettingsExchangeSyncFailure>(),
      ),
    );
  });
}
