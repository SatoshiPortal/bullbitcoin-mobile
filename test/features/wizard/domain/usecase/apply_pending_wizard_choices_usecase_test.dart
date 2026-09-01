import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockWizardRepository extends Mock implements WizardRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

void main() {
  late _MockWizardRepository wizard;
  late _MockSettingsRepository settings;
  late _MockWalletBackupFacade walletBackup;
  late ApplyPendingWizardChoicesUsecase usecase;

  setUpAll(() {
    registerFallbackValue(Language.unitedStatesEnglish);
    registerFallbackValue(AppThemeMode.system);
  });

  setUp(() {
    wizard = _MockWizardRepository();
    settings = _MockSettingsRepository();
    walletBackup = _MockWalletBackupFacade();
    usecase = ApplyPendingWizardChoicesUsecase(
      wizardRepository: wizard,
      settingsRepository: settings,
      walletBackup: walletBackup,
    );
    when(() => wizard.clearPending()).thenAnswer((_) async {});
    when(() => wizard.markComplete()).thenAnswer((_) async {});
    when(() => settings.setLanguage(any())).thenAnswer((_) async {});
    when(() => settings.setThemeMode(any())).thenAnswer((_) async {});
    when(() => settings.setCurrency(any())).thenAnswer((_) async {});
    when(
      () => settings.setErrorReportingEnabled(any()),
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
      verify(() => wizard.clearPending()).called(1);
      verify(() => wizard.markComplete()).called(1);
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

  test('flushes all four fields when all are touched', () async {
    when(() => wizard.readPending()).thenAnswer(
      (_) async => const WizardChoices(
        language: Language.franceFrench,
        themeMode: AppThemeMode.light,
        defaultCurrency: 'CAD',
        reportingConsent: false,
        touched: {
          WizardField.language,
          WizardField.themeMode,
          WizardField.defaultCurrency,
          WizardField.reportingConsent,
        },
      ),
    );

    await usecase.execute();

    verify(() => settings.setLanguage(Language.franceFrench)).called(1);
    verify(() => settings.setThemeMode(AppThemeMode.light)).called(1);
    verify(() => settings.setCurrency('CAD')).called(1);
    verify(() => settings.setErrorReportingEnabled(false)).called(1);
    verify(() => wizard.clearPending()).called(1);
    verify(() => wizard.markComplete()).called(1);
  });

  test('enables wallet backup before clearing the pending choice', () async {
    when(() => wizard.readPending()).thenAnswer(
      (_) async => const WizardChoices(
        metadataBackupEnabled: true,
        touched: {WizardField.metadataBackupEnabled},
      ),
    );
    when(
      () => walletBackup.setEnabled(true),
    ).thenAnswer((_) async => const Ok(null));

    final result = await usecase.execute();

    expect(result, const Ok<void, WizardFailure>(null));
    verifyInOrder([
      () => walletBackup.setEnabled(true),
      () => wizard.clearPending(),
      () => wizard.markComplete(),
    ]);
  });

  test(
    'applies settings but keeps the choice pending until a wallet exists',
    () async {
      when(() => wizard.readPending()).thenAnswer(
        (_) async => const WizardChoices(
          themeMode: AppThemeMode.dark,
          metadataBackupEnabled: true,
          touched: {WizardField.themeMode, WizardField.metadataBackupEnabled},
        ),
      );
      when(
        () => walletBackup.setEnabled(true),
      ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));

      final result = await usecase.execute();

      expect(result, const Err<void, WizardFailure>(WizardApplyFailure()));
      verify(() => settings.setThemeMode(AppThemeMode.dark)).called(1);
      verifyNever(() => wizard.clearPending());
      verifyNever(() => wizard.markComplete());
    },
  );
}
