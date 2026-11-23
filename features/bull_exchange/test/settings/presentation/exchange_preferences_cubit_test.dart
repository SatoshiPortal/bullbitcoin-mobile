import 'package:bull_exchange/src/settings/domain/entities/exchange_preferences.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_preferences_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetPreferences extends Mock
    implements GetExchangePreferencesUsecase {}

class _MockUpdatePreferences extends Mock
    implements UpdateExchangePreferencesUsecase {}

const _preferences = ExchangePreferences(
  language: 'EN',
  currency: 'CAD',
  emailNotificationsEnabled: true,
);

void main() {
  late _MockGetPreferences getPreferences;
  late _MockUpdatePreferences updatePreferences;

  setUpAll(() => registerFallbackValue(_preferences));

  setUp(() {
    getPreferences = _MockGetPreferences();
    updatePreferences = _MockUpdatePreferences();
  });

  ExchangePreferencesCubit build() {
    final cubit = ExchangePreferencesCubit(
      getExchangePreferencesUsecase: getPreferences,
      updateExchangePreferencesUsecase: updatePreferences,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<ExchangePreferencesCubit> buildLoaded([
    ExchangePreferences preferences = _preferences,
  ]) async {
    when(getPreferences.execute).thenAnswer((_) async => Ok(preferences));
    final cubit = build();
    await cubit.loadPreferences();
    return cubit;
  }

  test('a failed load holds the load failure', () async {
    when(getPreferences.execute).thenAnswer(
      (_) async => const Err(ExchangeSettingsAccountUnavailableFailure()),
    );
    final cubit = build();

    await cubit.loadPreferences();

    expect(cubit.state.preferences, isNull);
    expect(
      cubit.state.loadFailure,
      isA<ExchangeSettingsAccountUnavailableFailure>(),
    );
  });

  test('edits change only the edited field', () async {
    final cubit = await buildLoaded();

    cubit.updateLanguage('FR');
    cubit.updateCurrency('EUR');
    cubit.updateEmailNotifications(false);

    final preferences = cubit.state.preferences!;
    expect(preferences.language, 'FR');
    expect(preferences.currency, 'EUR');
    expect(preferences.emailNotificationsEnabled, isFalse);
  });

  test('save sends the edited preferences', () async {
    final cubit = await buildLoaded();
    when(
      () => updatePreferences.execute(
        loaded: any(named: 'loaded'),
        edited: any(named: 'edited'),
      ),
    ).thenAnswer((_) async => const Ok(null));

    cubit.updateLanguage('FR');
    await cubit.savePreferences();

    final [loaded, edited] = verify(
      () => updatePreferences.execute(
        loaded: captureAny(named: 'loaded'),
        edited: captureAny(named: 'edited'),
      ),
    ).captured.cast<ExchangePreferences>();
    expect(loaded, same(_preferences));
    expect(edited.language, 'FR');
    expect(edited.currency, 'CAD');
    expect(edited.emailNotificationsEnabled, isTrue);
    expect(cubit.state.isSaving, isFalse);
    expect(cubit.state.saveFailure, isNull);
  });

  test('a failed save holds the save failure', () async {
    final cubit = await buildLoaded();
    when(
      () => updatePreferences.execute(
        loaded: any(named: 'loaded'),
        edited: any(named: 'edited'),
      ),
    ).thenAnswer(
      (_) async => const Err(ExchangeSettingsPreferencesSaveFailure()),
    );

    await cubit.savePreferences();

    expect(cubit.state.isSaving, isFalse);
    expect(
      cubit.state.saveFailure,
      isA<ExchangeSettingsPreferencesSaveFailure>(),
    );
  });

  test('incomplete preferences are not saved', () async {
    final cubit = await buildLoaded(
      const ExchangePreferences(
        language: null,
        currency: 'CAD',
        emailNotificationsEnabled: true,
      ),
    );

    await cubit.savePreferences();

    verifyNever(
      () => updatePreferences.execute(
        loaded: any(named: 'loaded'),
        edited: any(named: 'edited'),
      ),
    );
  });
}
