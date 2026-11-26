import 'dart:io';
import 'dart:typed_data';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/backup_metadata_ui.dart';
import 'package:backup_metadata/src/domain/repositories/backup_metadata_repository.dart';
import 'package:backup_metadata/src/domain/usecases/apply_restore_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/configure_backup_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/discover_backups_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/get_backup_status_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/preview_restore_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/run_backup_usecase.dart';
import 'package:backup_metadata/src/presentation/backup_metadata_restore_cubit.dart';
import 'package:backup_metadata/src/presentation/backup_metadata_settings_cubit.dart';
import 'package:backup_metadata/src/ui/backup_metadata_flow.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Brightness, MaterialApp, Size, ThemeData;
import 'package:backup_metadata/setup.dart' show BackupLabelsPort;
import 'package:primitives/primitives.dart';

import '../support/fake_backup_secrets.dart';

final class _Repository implements BackupMetadataRepository {
  BackupDestination? destination;
  Set<String> included = {};
  final List<String> calls = [];
  ({BackupDestination? destination, Set<String> groups, bool delete})?
  configured;
  bool failRun = false;

  final group = BackupGroup(
    id: 'g',
    displayName: 'Savings',
    network: BitcoinNetwork.regtest,
    bitcoinWalletIds: ['w'],
    liquidWalletIds: [],
    bitcoinPublicDescriptors: ['d'],
    seedBackupVerified: true,
  );

  BackupRunStatus get _status => BackupRunStatus(
    destination: destination,
    groups: [
      BackupGroupStatus(
        group: group,
        included: included.contains('g'),
        lastDurableBackup: included.contains('g')
            ? DateTime.utc(2026, 11, 1)
            : null,
        failure: failRun && included.contains('g')
            ? const BackupMetadataUnexpectedFailure()
            : null,
      ),
    ],
    unsupported: const [],
    unattributedCount: 0,
  );

  @override
  Future<Result<BackupRunStatus, BackupMetadataFailure>> run() async {
    calls.add('run');
    return Ok(_status);
  }

  @override
  Future<Result<BackupRunStatus, BackupMetadataFailure>> status() async {
    calls.add('status');
    return Ok(_status);
  }

  @override
  Future<Result<List<DiscoveredBackup>, BackupMetadataFailure>> discover(
    BackupDestination destination,
  ) async {
    calls.add('discover:${destination.name}');
    return const Ok([]);
  }

  @override
  Future<Result<void, BackupMetadataFailure>> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    required bool deleteOwnedFiles,
  }) async {
    calls.add('configure');
    configured = (
      destination: destination,
      groups: groups,
      delete: deleteOwnedFiles,
    );
    this.destination = destination;
    included = groups;
    return const Ok(null);
  }
}

void main() {
  late _Repository repository;
  late BackupMetadataSettingsCubit settings;
  late BackupMetadataRestoreCubit restore;
  final l10n = lookupBackupMetadataLocalizations(const Locale('en'));
  var closed = 0;

  setUpAll(() async {
    final font = [
      File('assets/fonts/GolosText.ttf'),
      File('../../assets/fonts/GolosText.ttf'),
    ].firstWhere((file) => file.existsSync());
    await (FontLoader(
      BullTypography.fontFamily,
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final type = BullTypography.standard.resolved(testBullTheme.text);
    final secrets = FakeBackupSecrets();
    final labels = _NoLabels();
    settings = BackupMetadataSettingsCubit(
      GetBackupStatusUsecase(repository),
      ConfigureBackupUsecase(repository),
      RunBackupUsecase(repository),
    );
    restore = BackupMetadataRestoreCubit(
      DiscoverBackupsUsecase(repository),
      PreviewRestoreUsecase(labels, secrets),
      ApplyRestoreUsecase(labels, secrets),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        localizationsDelegates: const [
          backupMetadataLocalizationsDelegate,
          ...bullUiLocalizationsDelegates,
        ],
        theme: ThemeData(
          fontFamily: BullTypography.fontFamily,
          textTheme: type.toTextTheme(),
          extensions: bullUiExtensions(
            colors: testBullTheme,
            brightness: Brightness.light,
            typography: type,
          ),
        ),
        home: BackupMetadataFlow(
          settings: settings,
          restore: restore,
          destinations: const [BackupDestination.googleDrive],
          onClose: () => closed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _Repository();
    closed = 0;
  });

  testWidgets(
    'nothing is configured, written or listed until the user turns it on',
    (tester) async {
      await pump(tester);
      expect(find.text(l10n.continueAction), findsOneWidget);
      expect(repository.calls, ['status'], reason: 'reading the status only');
      expect(repository.configured, isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    },
  );

  testWidgets('turning on needs a destination and at least one wallet', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(l10n.continueAction));
    await tester.pumpAndSettle();
    final turnOn = find.text(l10n.turnOn);
    expect(turnOn, findsOneWidget);
    await tester.tap(turnOn, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repository.configured, isNull, reason: 'no wallet chosen yet');

    expect(find.byType(BackupMetadataWalletsView), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    await tester.tap(find.byType(BullSwitch), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.turnOn));
    await tester.pumpAndSettle();
    expect(repository.configured?.destination, BackupDestination.googleDrive);
    expect(repository.configured?.groups, {'g'});
    expect(repository.calls, containsAllInOrder(['configure', 'run']));
    expect(find.text(l10n.backUpNow), findsOneWidget);
  });

  testWidgets('turning off can delete the owned files and ends in the intro', (
    tester,
  ) async {
    repository
      ..destination = BackupDestination.googleDrive
      ..included = {'g'};
    await pump(tester);
    expect(find.text(l10n.turnOff), findsOneWidget);
    await tester.tap(find.text(l10n.turnOff));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.alsoDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.turnOff).last);
    await tester.pumpAndSettle();
    expect(repository.configured?.destination, isNull);
    expect(repository.configured?.delete, isTrue);
    expect(find.text(l10n.continueAction), findsOneWidget);
  });

  testWidgets('restore looks only in the configured destination', (
    tester,
  ) async {
    repository
      ..destination = BackupDestination.googleDrive
      ..included = {'g'};
    await pump(tester);
    await tester.tap(find.text(l10n.restoreFromBackup));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('discover:googleDrive'));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('a failed backup is reported with a translated reason', (
    tester,
  ) async {
    repository
      ..destination = BackupDestination.googleDrive
      ..included = {'g'}
      ..failRun = true;
    await pump(tester);
    expect(find.text(l10n.actionNeeded), findsOneWidget);
    expect(find.text(l10n.failureUnexpected), findsWidgets);
  });
}

final class _NoLabels extends Fake implements BackupLabelsPort {}
