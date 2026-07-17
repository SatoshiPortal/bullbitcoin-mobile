import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubBackupSettingsCubit extends Cubit<BackupSettingsState>
    implements BackupSettingsCubit {
  _StubBackupSettingsCubit(super.initialState);

  final List<({bool enabled, bool disclosureAccepted})> enabledCalls = [];
  int manualBackupCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> checkBackupStatus() async {}

  @override
  Future<void> setMetadataBackupEnabled({
    required bool enabled,
    required bool disclosureAccepted,
  }) async {
    enabledCalls.add((
      enabled: enabled,
      disclosureAccepted: disclosureAccepted,
    ));
  }

  @override
  Future<void> backupMetadataNow() async {
    manualBackupCalls++;
  }

  @override
  Future<void> deleteRemoteMetadata() async {
    deleteCalls++;
  }

  void showDeleted() {
    emit(
      state.copyWith(
        metadataActionStatus: WalletMetadataBackupActionStatus.deleted,
      ),
    );
  }
}

void main() {
  tearDown(() async {
    await locator.reset();
  });

  testWidgets('requires explicit Bullnym storage disclosure before enabling', (
    tester,
  ) async {
    final cubit = _StubBackupSettingsCubit(BackupSettingsState());
    await _pump(tester, cubit);

    expect(find.text('Wallet metadata backup'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Back up private wallet metadata?'), findsOneWidget);
    expect(find.textContaining('on Bullnym'), findsOneWidget);
    expect(
      find.textContaining('separate identity and encryption key'),
      findsOneWidget,
    );
    expect(
      find.textContaining('delete the remote copy separately'),
      findsOneWidget,
    );
    expect(cubit.enabledCalls, isEmpty);

    await tester.tap(find.text('Enable backup'));
    await tester.pumpAndSettle();

    expect(cubit.enabledCalls, [(enabled: true, disclosureAccepted: true)]);
  });

  testWidgets('cancel leaves metadata backup disabled', (tester) async {
    final cubit = _StubBackupSettingsCubit(BackupSettingsState());
    await _pump(tester, cubit);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cubit.enabledCalls, isEmpty);
  });

  testWidgets('disabling does not require a disclosure decision', (
    tester,
  ) async {
    final cubit = _StubBackupSettingsCubit(
      BackupSettingsState(metadataBackupEnabled: true),
    );
    await _pump(tester, cubit);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(cubit.enabledCalls, [(enabled: false, disclosureAccepted: false)]);
  });

  testWidgets('deletes the remote copy only after confirmation', (
    tester,
  ) async {
    final cubit = _StubBackupSettingsCubit(
      BackupSettingsState(status: BackupSettingsStatus.success),
    );
    await _pump(tester, cubit);

    await tester.tap(find.text('Delete remote backup'));
    await tester.pumpAndSettle();
    expect(find.text('Delete encrypted metadata backup?'), findsOneWidget);
    expect(cubit.deleteCalls, 0);

    await tester.tap(find.text('Delete remote backup').last);
    await tester.pumpAndSettle();
    expect(cubit.deleteCalls, 1);
  });

  testWidgets('shows the last metadata backup time', (tester) async {
    final cubit = _StubBackupSettingsCubit(
      BackupSettingsState(
        status: BackupSettingsStatus.success,
        metadataBackupEnabled: true,
        metadataBackupLastVerifiedAt: DateTime.utc(2026, 7, 16, 12),
      ),
    );
    await _pump(tester, cubit);

    expect(find.textContaining('Last backup:'), findsOneWidget);
  });

  testWidgets('reports successful remote deletion', (tester) async {
    final cubit = _StubBackupSettingsCubit(
      BackupSettingsState(status: BackupSettingsStatus.success),
    );
    await _pump(tester, cubit);
    cubit.showDeleted();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Remote wallet metadata backup deleted.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('blocked recovery state disables manual publication', (
    tester,
  ) async {
    final cubit = _StubBackupSettingsCubit(
      BackupSettingsState(
        metadataBackupEnabled: true,
        metadataBackupDirty: true,
        metadataBackupBlocked: true,
      ),
    );
    await _pump(tester, cubit);

    expect(find.text('Blocked to protect newer recovery data'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Back up now'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('manual action is available for an enabled unblocked backup', (
    tester,
  ) async {
    final cubit = _StubBackupSettingsCubit(
      BackupSettingsState(
        metadataBackupEnabled: true,
        metadataBackupDirty: true,
      ),
    );
    await _pump(tester, cubit);

    await tester.tap(find.text('Back up now'));
    await tester.pump();

    expect(cubit.manualBackupCalls, 1);
  });
}

Future<void> _pump(WidgetTester tester, _StubBackupSettingsCubit cubit) async {
  locator.registerFactory<BackupSettingsCubit>(() => cubit);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const BackupSettingsScreen(),
    ),
  );
  await tester.pump();
}
