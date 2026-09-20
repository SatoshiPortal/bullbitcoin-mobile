import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_settings_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Cubit extends Mock implements DataBackupSettingsCubit {}

void main() {
  final loc = AppLocalizationsEn();
  late _Cubit cubit;
  setUp(() {
    cubit = _Cubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.setEnabled(any())).thenAnswer((_) async {});
    when(cubit.refresh).thenAnswer((_) async {});
    when(() => cubit.refresh(retryPublication: true)).thenAnswer((_) async {});
    when(() => cubit.delete(confirmed: true)).thenAnswer((_) async {});
  });
  Future<void> pump(WidgetTester tester, DataBackupSettingsState state) async {
    when(() => cubit.state).thenReturn(state);
    await tester.binding.setSurfaceSize(const Size(460, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<DataBackupSettingsCubit>.value(
          value: cubit,
          child: DataBackupSettingsScreen(
            onContents: (_) async {},
            onWords: () async {},
            onRecovery: () async {},
            onRecoverWords: () async {},
            fileActions: const SizedBox.shrink(),
            dataExports: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an action in progress has visible feedback', (tester) async {
    await pump(
      tester,
      const DataBackupSettingsState(
        working: true,
        data: DataBackupStatus(control: WalletBackupControl(enabled: false)),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('a publication network failure offers retry', (tester) async {
    await pump(
      tester,
      const DataBackupSettingsState(
        data: DataBackupStatus(
          control: WalletBackupControl(enabled: true),
          failure: BackupSettingsNetworkFailure(),
        ),
      ),
    );
    expect(find.text(loc.retry), findsOneWidget);
    await tester.tap(find.text(loc.retry));
    verify(() => cubit.refresh(retryPublication: true)).called(1);
  });

  testWidgets('cancelled enable never changes the consent choice', (
    tester,
  ) async {
    await pump(
      tester,
      const DataBackupSettingsState(
        data: DataBackupStatus(control: WalletBackupControl()),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('data-backup-enabled')));
    await tester.pumpAndSettle();
    expect(find.text(loc.dataBackupConsentBody), findsOneWidget);
    await tester.tap(find.text(loc.cancelButton));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.setEnabled(any()));
  });

  testWidgets('a failed status and active upload still leave off available', (
    tester,
  ) async {
    await pump(
      tester,
      const DataBackupSettingsState(
        working: true,
        data: DataBackupStatus(
          control: WalletBackupControl(enabled: true),
          publishing: true,
          failure: BackupSettingsNetworkFailure(),
        ),
      ),
    );
    final control = tester.widget<BullSwitch>(
      find.byKey(const ValueKey('data-backup-enabled')),
    );
    expect(control.onChanged, isNotNull);
    await tester.tap(find.byKey(const ValueKey('data-backup-enabled')));
    await tester.pump();
    verify(() => cubit.setEnabled(false)).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'delete while on explains off and never deletes or disables implicitly',
    (tester) async {
      await pump(
        tester,
        const DataBackupSettingsState(
          data: DataBackupStatus(control: WalletBackupControl(enabled: true)),
        ),
      );
      final entry = find.byKey(const ValueKey('data-backup-delete'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text(loc.dataBackupDeleteRequiresDisabled), findsOneWidget);
      verifyNever(() => cubit.delete(confirmed: true));
      verifyNever(() => cubit.setEnabled(any()));
    },
  );

  testWidgets('cancelled destructive confirmation has no delete action', (
    tester,
  ) async {
    await pump(
      tester,
      const DataBackupSettingsState(
        data: DataBackupStatus(control: WalletBackupControl(enabled: false)),
      ),
    );
    final entry = find.byKey(const ValueKey('data-backup-delete'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.cancelButton));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.delete(confirmed: true));
  });
}
