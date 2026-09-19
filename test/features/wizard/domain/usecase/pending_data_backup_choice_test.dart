import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  late WizardRepositoryImpl wizard;
  late _Settings settings;
  late _Backups backups;
  late ApplyPendingWizardChoicesUsecase apply;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    wizard = WizardRepositoryImpl(WizardLocalDatasourceImpl());
    settings = _Settings();
    backups = _Backups();
    when(
      () => settings.setThemeMode(AppThemeMode.dark),
    ).thenAnswer((_) async {});
    when(
      () => backups.setEnabled(any(), onlyIfUndecided: true),
    ).thenAnswer((_) async => const Ok(null));
    apply = ApplyPendingWizardChoicesUsecase(
      wizardRepository: wizard,
      settingsRepository: settings,
      walletBackup: backups,
    );
  });
  for (final enabled in [false, true]) {
    test(
      'saved choice $enabled survives pre-seed flush and applies only when ready',
      () async {
        expect(
          await wizard.savePending(
            WizardChoices(
              themeMode: AppThemeMode.dark,
              dataBackupEnabled: enabled,
              touched: {WizardField.themeMode, WizardField.dataBackupEnabled},
            ),
          ),
          isA<Ok>(),
        );
        expect(await apply.execute(), isA<Ok>());
        verifyZeroInteractions(backups);
        verify(() => settings.setThemeMode(AppThemeMode.dark)).called(1);
        final reopened = WizardRepositoryImpl(WizardLocalDatasourceImpl());
        final pending = await reopened.readPending();
        expect(pending!.dataBackupEnabled, enabled);
        expect(pending.touched, {WizardField.dataBackupEnabled});
        expect(await apply.execute(backupReady: true), isA<Ok>());
        verify(
          () => backups.setEnabled(enabled, onlyIfUndecided: true),
        ).called(1);
        expect(await reopened.readPending(), isNull);
        verifyNoMoreInteractions(settings);
      },
    );
  }
  test('no answer never calls the backup owner', () async {
    expect(await apply.execute(backupReady: true), isA<Ok>());
    verifyZeroInteractions(backups);
    verifyZeroInteractions(settings);
  });
  test(
    'a failed enable preserves the choice for a later ready attempt',
    () async {
      expect(
        await wizard.savePending(
          const WizardChoices(
            dataBackupEnabled: true,
            touched: {WizardField.dataBackupEnabled},
          ),
        ),
        isA<Ok>(),
      );
      when(
        () => backups.setEnabled(true, onlyIfUndecided: true),
      ).thenAnswer((_) async => const Err(WalletBackupCredentialFailure()));
      expect(await apply.execute(backupReady: true), isA<Err>());
      expect((await wizard.readPending())!.dataBackupEnabled, isTrue);
      when(
        () => backups.setEnabled(true, onlyIfUndecided: true),
      ).thenAnswer((_) async => const Ok(null));
      expect(await apply.execute(backupReady: true), isA<Ok>());
      expect(await wizard.readPending(), isNull);
    },
  );
}
