import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWizardRepository extends Mock implements WizardRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockWizardRepository wizard;
  late _MockSettingsRepository settings;
  late ApplyPendingWizardChoicesUsecase usecase;

  setUpAll(() {
    registerFallbackValue(Language.unitedStatesEnglish);
    registerFallbackValue(AppThemeMode.system);
  });

  setUp(() {
    wizard = _MockWizardRepository();
    settings = _MockSettingsRepository();
    usecase = ApplyPendingWizardChoicesUsecase(
      wizardRepository: wizard,
      settingsRepository: settings,
    );
    when(() => wizard.clearPending()).thenAnswer((_) async {});
    when(() => wizard.markComplete()).thenAnswer((_) async {});
    when(() => settings.setLanguage(any())).thenAnswer((_) async {});
    when(() => settings.setThemeMode(any())).thenAnswer((_) async {});
    when(() => settings.setCurrency(any())).thenAnswer((_) async {});
    when(
      () => settings.setErrorReportingEnabled(any()),
    ).thenAnswer((_) async {});
    when(
      () => settings.setUseCompactBlockFiltersByDefault(any()),
    ).thenAnswer((_) async {});
  });

  test('short-circuits when nothing is staged', () async {
    when(() => wizard.readPending()).thenAnswer((_) async => null);

    await usecase.execute();

    verify(() => wizard.readPending()).called(1);
    verifyNoMoreInteractions(wizard);
    verifyZeroInteractions(settings);
  });

  test(
    'flushes only fields the user touched then clears + marks complete',
    () async {
      when(() => wizard.readPending()).thenAnswer(
        (_) async => const WizardChoices(
          language: Language.franceFrench,
          themeMode: AppThemeMode.dark,
          defaultCurrency: 'EUR',
          reportingConsent: true,
          // theme + consent only — language and currency must NOT be flushed.
          touched: {WizardField.themeMode, WizardField.reportingConsent},
        ),
      );

      await usecase.execute();

      verify(() => settings.setThemeMode(AppThemeMode.dark)).called(1);
      verify(() => settings.setErrorReportingEnabled(true)).called(1);
      verifyNever(() => settings.setLanguage(any()));
      verifyNever(() => settings.setCurrency(any()));
      verifyNever(() => settings.setUseCompactBlockFiltersByDefault(any()));
      verify(() => wizard.clearPending()).called(1);
      verify(() => wizard.markComplete()).called(1);
    },
  );

  test('flushes privateBitcoinSync only when touched', () async {
    when(() => wizard.readPending()).thenAnswer(
      (_) async => const WizardChoices(
        privateBitcoinSync: true,
        touched: {WizardField.privateBitcoinSync},
      ),
    );

    await usecase.execute();

    verify(() => settings.setUseCompactBlockFiltersByDefault(true)).called(1);
    verifyNever(() => settings.setThemeMode(any()));
    verifyNever(() => settings.setLanguage(any()));
    verifyNever(() => settings.setCurrency(any()));
    verifyNever(() => settings.setErrorReportingEnabled(any()));
  });

  test(
    'does not flush privateBitcoinSync when untouched, even if true',
    () async {
      when(() => wizard.readPending()).thenAnswer(
        (_) async => const WizardChoices(
          themeMode: AppThemeMode.dark,
          privateBitcoinSync: true,
          touched: {WizardField.themeMode},
        ),
      );

      await usecase.execute();

      verifyNever(() => settings.setUseCompactBlockFiltersByDefault(any()));
    },
  );

  test(
    'skips reportingConsent flush when value is null even if touched',
    () async {
      when(() => wizard.readPending()).thenAnswer(
        (_) async => const WizardChoices(
          // touched but value left null — apply must not push a bogus
          // false to settings.
          touched: {WizardField.reportingConsent},
        ),
      );

      await usecase.execute();

      verifyNever(() => settings.setErrorReportingEnabled(any()));
      verify(() => wizard.clearPending()).called(1);
      verify(() => wizard.markComplete()).called(1);
    },
  );

  test('flushes all five fields when all are touched', () async {
    when(() => wizard.readPending()).thenAnswer(
      (_) async => const WizardChoices(
        language: Language.franceFrench,
        themeMode: AppThemeMode.light,
        defaultCurrency: 'CAD',
        reportingConsent: false,
        privateBitcoinSync: true,
        touched: {
          WizardField.language,
          WizardField.themeMode,
          WizardField.defaultCurrency,
          WizardField.reportingConsent,
          WizardField.privateBitcoinSync,
        },
      ),
    );

    await usecase.execute();

    verify(() => settings.setLanguage(Language.franceFrench)).called(1);
    verify(() => settings.setThemeMode(AppThemeMode.light)).called(1);
    verify(() => settings.setCurrency('CAD')).called(1);
    verify(() => settings.setErrorReportingEnabled(false)).called(1);
    verify(() => settings.setUseCompactBlockFiltersByDefault(true)).called(1);
    verify(() => wizard.clearPending()).called(1);
    verify(() => wizard.markComplete()).called(1);
  });
}
