import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real cubit so each posture can be pumped directly. The
/// screen resolves it from the locator, so registering the fake is enough.
class _FakeBackupSettingsCubit extends Cubit<BackupSettingsState>
    implements BackupSettingsCubit {
  _FakeBackupSettingsCubit(super.initialState);

  @override
  Future<void> checkBackupStatus() async {}
}

void main() {
  late AppLocalizations loc;

  setUpAll(
    () async => loc = await AppLocalizations.delegate.load(const Locale('en')),
  );

  tearDown(() async {
    if (locator.isRegistered<BackupSettingsCubit>()) {
      await locator.reset();
    }
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required bool physicalTested,
    required bool vaultTested,
    DateTime? lastPhysicalBackup,
    DateTime? lastEncryptedBackup,
    BackupSettingsStatus status = BackupSettingsStatus.success,
  }) async {
    final state = BackupSettingsState(
      isDefaultPhysicalBackupTested: physicalTested,
      isDefaultEncryptedBackupTested: vaultTested,
      lastPhysicalBackup: lastPhysicalBackup,
      lastEncryptedBackup: lastEncryptedBackup,
      status: status,
    );
    locator.registerFactory<BackupSettingsCubit>(
      () => _FakeBackupSettingsCubit(state),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BackupSettingsScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('urges a backup, and only that, when nothing is backed up', (
    tester,
  ) async {
    await pumpScreen(tester, physicalTested: false, vaultTested: false);

    expect(find.text(loc.backupSettingsHeroBackUpTitle), findsOneWidget);
    expect(find.text(loc.backupSettingsStartBackupAction), findsOneWidget);
    expect(find.text(loc.backupHealthReminderTitle), findsNothing);
    // Nothing to test yet, so no test-backup row.
    expect(find.text(loc.backupSettingsTestBackup), findsNothing);
  });

  testWidgets('asks a vault-only wallet for a physical backup', (tester) async {
    await pumpScreen(
      tester,
      physicalTested: false,
      vaultTested: true,
      lastEncryptedBackup: DateTime.now(),
    );

    expect(find.text(loc.backupHealthReminderTitle), findsOneWidget);
    expect(find.text(loc.backupHealthAddPhysicalBackupAction), findsOneWidget);
    expect(find.text(loc.backupSettingsHeroBackUpTitle), findsNothing);
  });

  testWidgets('says nothing extra when the physical backup is fresh', (
    tester,
  ) async {
    final testedAt = DateTime.now().subtract(const Duration(days: 30));
    await pumpScreen(
      tester,
      physicalTested: true,
      vaultTested: true,
      lastPhysicalBackup: testedAt,
      lastEncryptedBackup: testedAt,
    );

    expect(find.text(loc.backupHealthReminderTitle), findsNothing);
    expect(find.text(loc.backupSettingsHeroBackUpTitle), findsNothing);
    expect(find.text(loc.backupHealthTestBackupAction), findsNothing);
    // The rows still carry the facts.
    expect(find.text(loc.backupSettingsTested), findsNWidgets(2));
  });

  testWidgets('asks for a test when the physical backup has gone stale', (
    tester,
  ) async {
    final testedAt = DateTime.now().subtract(const Duration(days: 400));
    await pumpScreen(
      tester,
      physicalTested: true,
      vaultTested: true,
      lastPhysicalBackup: testedAt,
      lastEncryptedBackup: DateTime.now(),
    );

    expect(find.text(loc.backupHealthReminderTitle), findsOneWidget);
    expect(find.text(loc.backupHealthTestBackupAction), findsOneWidget);
  });

  testWidgets('a fresh vault does not excuse a stale physical backup', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      physicalTested: true,
      vaultTested: true,
      lastPhysicalBackup: DateTime.now().subtract(const Duration(days: 730)),
      lastEncryptedBackup: DateTime.now(),
    );

    expect(find.text(loc.backupHealthTestBackupAction), findsOneWidget);
  });

  testWidgets('states when the physical backup was last tested', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      physicalTested: true,
      vaultTested: false,
      lastPhysicalBackup: DateTime.now().subtract(const Duration(days: 60)),
    );

    expect(find.textContaining('Last tested'), findsWidgets);
  });

  testWidgets('renders no hero before the first load resolves', (tester) async {
    await pumpScreen(
      tester,
      physicalTested: false,
      vaultTested: false,
      status: BackupSettingsStatus.loading,
    );

    expect(find.text(loc.backupSettingsHeroBackUpTitle), findsNothing);
    expect(find.text(loc.backupSettingsStartBackupAction), findsNothing);
  });

  // Availability is not encouragement: the hero goes quiet once a physical
  // backup is fresh, but adding another backup must never stop being possible.
  group('the backup action is always available', () {
    final now = DateTime.now();
    // The zero-backup state is deliberately absent: there the hero itself
    // renders START BACKUP, so the menu row would be a second identical entry
    // a few pixels below it. Covered by its own test after this group.
    final postures = <String, Map<String, Object?>>{
      'vault only': {'physical': false, 'vault': true, 'vaultAt': now},
      'physical fresh': {
        'physical': true,
        'vault': false,
        'physicalAt': now.subtract(const Duration(days: 30)),
      },
      'physical stale': {
        'physical': true,
        'vault': false,
        'physicalAt': now.subtract(const Duration(days: 400)),
      },
      'both': {
        'physical': true,
        'vault': true,
        'physicalAt': now.subtract(const Duration(days: 30)),
        'vaultAt': now,
      },
    };

    for (final entry in postures.entries) {
      testWidgets(entry.key, (tester) async {
        final p = entry.value;
        await pumpScreen(
          tester,
          physicalTested: p['physical']! as bool,
          vaultTested: p['vault']! as bool,
          lastPhysicalBackup: p['physicalAt'] as DateTime?,
          lastEncryptedBackup: p['vaultAt'] as DateTime?,
        );

        expect(find.text(loc.backupSettingsStartBackup), findsOneWidget);
      });
    }
  });

  testWidgets(
    'the zero-backup hero offers START BACKUP without a duplicate menu row',
    (tester) async {
      await pumpScreen(tester, physicalTested: false, vaultTested: false);

      // The hero's own CTA is present…
      expect(find.text(loc.backupSettingsStartBackupAction), findsOneWidget);
      // …and the menu row offering the same action is suppressed here only.
      expect(find.text(loc.backupSettingsStartBackup), findsNothing);
    },
  );

  testWidgets('names the encrypted vault menu row after the status row', (
    tester,
  ) async {
    await pumpScreen(tester, physicalTested: false, vaultTested: false);

    expect(find.text(loc.backupSettingsEncryptedVaultSettings), findsOneWidget);
  });
}
