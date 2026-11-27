import 'dart:io';
import 'dart:typed_data';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/backup_metadata_ui.dart';
import 'package:backup_metadata/setup.dart'
    show BackupLabelsPort, BackupSessionRef, SecretsRestoreReport;
import 'package:backup_metadata/src/domain/content_sanitizer.dart';
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
import 'package:labels/backup.dart';
import 'package:material_ui/material_ui.dart'
    show Brightness, MaterialApp, Size, ThemeData;
import 'package:primitives/primitives.dart';

import '../support/fake_backup_secrets.dart';

final class _Repository implements BackupMetadataRepository {
  BackupDestination? destination;
  String? account = 'user@example.test';
  Set<String> included = {};
  final List<String> calls = [];
  ({BackupDestination? destination, Set<String> groups, bool delete})?
  configured;
  BackupDestination? staged;
  bool failRun = false;
  int excluded = 0;
  bool failConfigure = false;
  bool accountChanged = false;
  List<DiscoveredBackup> found = const [];

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
    account: account,
    groups: [
      BackupGroupStatus(
        group: group,
        included: included.contains('g'),
        excluded: included.contains('g') ? excluded : 0,
        lastDurableBackup: included.contains('g')
            ? DateTime.utc(2026, 11, 1)
            : null,
        failure: accountChanged && included.contains('g')
            ? const BackupMetadataAccountChangedFailure()
            : failRun && included.contains('g')
            ? const BackupMetadataUnexpectedFailure()
            : null,
        actionNeeded: accountChanged && included.contains('g')
            ? BackupActionReason.accountChanged
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
  Future<Result<BackupSummary, BackupMetadataFailure>> summary() async =>
      Ok(BackupSummary(enabled: destination != null && included.isNotEmpty));

  @override
  Future<Result<BackupConfirmation, BackupMetadataFailure>> stage(
    BackupDestination destination,
    Set<String> groups,
  ) async {
    calls.add('stage');
    if (failConfigure) return const Err(BackupMetadataUnexpectedFailure());
    staged = destination;
    return Ok(
      BackupConfirmation(
        destination: destination,
        account: account ?? 'unknown',
        generation: 0,
        session: FakeSession('scope'),
        token: 'token',
        groups: groups,
      ),
    );
  }

  @override
  Future<Result<void, BackupMetadataFailure>> discardStaged() async {
    calls.add('discard');
    staged = null;
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupMetadataFailure>> include(
    Set<String> groups,
    BackupConfirmation confirmation,
  ) async {
    calls.add('include');
    included = groups;
    destination = confirmation.destination;
    accountChanged = false;
    return const Ok(null);
  }

  @override
  Future<Result<List<DiscoveredBackup>, BackupMetadataFailure>> discover(
    BackupDestination destination,
  ) async {
    calls.add('discover:${destination.name}');
    return Ok(found);
  }

  @override
  Future<Result<void, BackupMetadataFailure>> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    required bool deleteOwnedFiles,
  }) async {
    calls.add('configure');
    if (failConfigure && destination != null) {
      return const Err(BackupMetadataUnexpectedFailure());
    }
    configured = (
      destination: destination,
      groups: groups,
      delete: deleteOwnedFiles,
    );
    this.destination = destination;
    included = groups;
    if (destination != null) accountChanged = false;
    return const Ok(null);
  }
}

/// Labels that preview a plan and apply when allowed, counting each effect.
final class _Labels implements BackupLabelsPort {
  bool failApply = false;
  void Function()? onApply;
  int previews = 0;
  int applies = 0;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupSessionRef session,
    BackupGroup group,
  ) async => Ok(
    LabelsSnapshot(records: const [], unattributedCount: 0, skippedCount: 0),
  );

  @override
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupSessionRef session,
    BackupGroup group,
    LabelsSnapshot incoming,
  ) async {
    previews++;
    return Ok(
      MergePlan(
        groupId: group.id,
        baseDigest: 'base',
        additions: const [],
        unchanged: 0,
        conflicts: const [],
        freezes: const [],
      ),
    );
  }

  @override
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    BackupSessionRef session,
    MergePlan plan,
    MergeChoices choices,
  ) async {
    applies++;
    onApply?.call();
    if (failApply) return const Err(BackupMetadataUnexpectedFailure());
    return Ok(
      ApplyReport(
        labelsApplied: 3,
        labelsUnchanged: 0,
        labelsRejected: const {},
        freezes: const {},
      ),
    );
  }
}

SecretsRestoreReport _secretsReport({
  int added = 0,
  bool refused = false,
  int labels = 0,
}) => SecretsRestoreReport(
  walletsMatched: 1,
  walletsUnmatched: 0,
  walletLabelsApplied: labels,
  walletBirthdaysApplied: 0,
  derivationsAdded: added,
  derivationsUpdated: 0,
  derivationsRefused: refused,
);

void main() {
  late _Repository repository;
  late _Labels labels;
  late FakeBackupSecrets secrets;
  var excludedInFile = 0;
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

  DiscoveredBackup backup({BackupContent? content}) => DiscoveredBackup(
    group: repository.group,
    destination: BackupDestination.googleDrive,
    storedAt: DateTime.utc(2026, 11, 1),
    content:
        content ??
        BackupContent(
          excluded: excludedInFile,
          labels: LabelsSnapshot(
            records: const [],
            unattributedCount: 0,
            skippedCount: 0,
          ),
          wallets: const [],
          derivations: const [],
        ),
    scope: secrets.live,
  );

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final type = BullTypography.standard.resolved(testBullTheme.text);
    settings = BackupMetadataSettingsCubit(
      GetBackupStatusUsecase(repository),
      ConfigureBackupUsecase(repository),
      RunBackupUsecase(repository),
    );
    restore = BackupMetadataRestoreCubit(
      DiscoverBackupsUsecase(repository),
      PreviewRestoreUsecase(labels),
      ApplyRestoreUsecase(labels, secrets),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('fr')],
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
    labels = _Labels();
    secrets = FakeBackupSecrets();
    closed = 0;
    excludedInFile = 0;
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Intro to the wallets view with Drive chosen and the wallet switched on.
  Future<void> chooseDriveAndWallet(WidgetTester tester) async {
    await tapText(tester, l10n.googleDrive);
    await tapText(tester, l10n.continueAction);
    await tester.tap(find.byType(BullSwitch), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group('turning on', () {
    testWidgets('nothing is preselected and nothing is read or sent', (
      tester,
    ) async {
      await pump(tester);
      expect(repository.calls, ['status'], reason: 'reading the status only');
      expect(find.text(l10n.googleDrive), findsOneWidget);
      expect(find.text(l10n.iCloud), findsNothing);
      expect(find.text(l10n.customLocation), findsNothing);
      // Continue stays disabled until a provider is picked.
      await tester.tap(find.text(l10n.continueAction), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.walletsTitle), findsNothing);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets(
      'the provider, the account and the wallets are confirmed first',
      (tester) async {
        await pump(tester);
        await chooseDriveAndWallet(tester);
        await tapText(tester, l10n.turnOn);

        expect(find.text(l10n.confirmTitle), findsOneWidget);
        expect(
          find.text(l10n.confirmAccount('user@example.test')),
          findsOneWidget,
        );
        expect(find.text('• Savings'), findsOneWidget);
        // The destination is stored with no wallet: nothing can be sent yet.
        expect(repository.staged, BackupDestination.googleDrive);
        expect(repository.destination, isNull);
        expect(repository.calls, isNot(contains('run')));
        expect(repository.calls, isNot(contains('include')));

        await tapText(tester, l10n.confirmAction);
        expect(
          repository.calls,
          containsAllInOrder(['stage', 'include', 'run']),
        );
        expect(repository.included, {'g'});
        expect(find.text(l10n.backUpNow), findsOneWidget);
      },
    );

    testWidgets('declining sends nothing and turns it off again', (
      tester,
    ) async {
      await pump(tester);
      await chooseDriveAndWallet(tester);
      await tapText(tester, l10n.turnOn);
      await tapText(tester, l10n.cancel);

      expect(repository.calls, isNot(contains('run')));
      expect(repository.calls, isNot(contains('include')));
      expect(repository.calls, contains('discard'));
      expect(repository.destination, isNull);
      expect(find.text(l10n.continueAction), findsOneWidget);
    });

    testWidgets('an interrupted turn-on starts again from the intro', (
      tester,
    ) async {
      // A destination was granted, but never confirmed.
      repository.staged = BackupDestination.googleDrive;
      await pump(tester);
      expect(find.text(l10n.continueAction), findsOneWidget);
      expect(find.text(l10n.backUpNow), findsNothing);
      expect(repository.calls, isNot(contains('run')));
    });

    testWidgets('a failed configuration stops before any backup', (
      tester,
    ) async {
      repository.failConfigure = true;
      await pump(tester);
      await chooseDriveAndWallet(tester);
      await tapText(tester, l10n.turnOn);

      expect(repository.calls, isNot(contains('run')));
      expect(repository.calls, isNot(contains('include')));
      expect(find.text(l10n.confirmTitle), findsNothing);
      expect(repository.included, isEmpty);
      // The failure is shown, then the toast goes away.
      expect(find.text(l10n.failureUnexpected), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
      'a changed account needs a new choice before anything is sent',
      (tester) async {
        repository
          ..destination = BackupDestination.googleDrive
          ..included = {'g'}
          ..accountChanged = true;
        await pump(tester);
        expect(find.text(l10n.actionNeeded), findsOneWidget);
        expect(find.text(l10n.failureAccountChanged), findsWidgets);

        await tapText(tester, l10n.reconnect(l10n.googleDrive));
        expect(find.text(l10n.confirmTitle), findsOneWidget);
        expect(repository.calls, isNot(contains('run')));
        await tapText(tester, l10n.cancel);
        expect(repository.calls, isNot(contains('run')));
      },
    );
  });

  group('turning off and restoring', () {
    testWidgets(
      'turning off can delete the owned files and ends in the intro',
      (tester) async {
        repository
          ..destination = BackupDestination.googleDrive
          ..included = {'g'};
        await pump(tester);
        await tapText(tester, l10n.turnOff);
        await tapText(tester, l10n.alsoDelete);
        await tester.tap(find.text(l10n.turnOff).last);
        await tester.pumpAndSettle();
        expect(repository.configured?.destination, isNull);
        expect(repository.configured?.delete, isTrue);
        expect(find.text(l10n.continueAction), findsOneWidget);
      },
    );

    testWidgets(
      'on a new phone restore is reachable without turning anything on',
      (tester) async {
        await pump(tester);
        expect(find.text(l10n.restoreFromBackup), findsOneWidget);
        await tapText(tester, l10n.restoreFromBackup);
        expect(repository.calls, contains('discover:googleDrive'));
        expect(repository.calls, isNot(contains('configure')));
        expect(repository.calls, isNot(contains('include')));
        expect(repository.calls, isNot(contains('run')));
      },
    );

    testWidgets('restore looks only in the configured destination', (
      tester,
    ) async {
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'};
      await pump(tester);
      await tapText(tester, l10n.restoreFromBackup);
      expect(repository.calls, contains('discover:googleDrive'));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('notes left out as secrets are counted, never shown', (
      tester,
    ) async {
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'}
        ..excluded = 2;
      await pump(tester);
      expect(find.text(l10n.excludedRecords(2)), findsOneWidget);
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
  });

  group('a restore result', () {
    testWidgets('the preview reports fields filtered while reading', (
      tester,
    ) async {
      excludedInFile = 3;
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'}
        ..found = [backup()];
      await pump(tester);
      await tapText(tester, l10n.restoreFromBackup);
      await tapText(tester, 'Savings');
      expect(find.text(l10n.restoreFilteredFields(3)), findsOneWidget);
      expect(find.text(l10n.excludedRecords(3)), findsNothing);
      expect(find.text(l10n.labelsRejected(3)), findsNothing);
      expect(find.text(l10n.differencesResolved(3)), findsNothing);
      await tapText(tester, l10n.restore);
      expect(find.text(l10n.restoreFilteredFields(3)), findsOneWidget);
    });

    testWidgets('zero read-time filtered fields are not reported', (
      tester,
    ) async {
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'}
        ..found = [backup()];
      await pump(tester);
      await tapText(tester, l10n.restoreFromBackup);
      await tapText(tester, 'Savings');
      expect(find.text(l10n.restoreFilteredFields(0)), findsNothing);
      await tapText(tester, l10n.restore);
      expect(find.text(l10n.restoreFilteredFields(0)), findsNothing);
    });

    testWidgets('the read-time warning is localized in French', (tester) async {
      excludedInFile = 2;
      final french = lookupBackupMetadataLocalizations(const Locale('fr'));
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'}
        ..found = [backup()];
      await pump(tester, locale: const Locale('fr'));
      await tapText(tester, french.restoreFromBackup);
      await tapText(tester, 'Savings');
      expect(find.text(french.restoreFilteredFields(2)), findsOneWidget);
      await tapText(tester, french.restore);
      expect(find.text(french.restoreFilteredFields(2)), findsOneWidget);
    });

    testWidgets('filtered reference and text never appear in restore screens', (
      tester,
    ) async {
      const phrase =
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon about';
      final content = sanitizeContent(
        BackupContent(
          labels: LabelsSnapshot(
            records: [
              BackupLabelRecord(
                chain: BackupLabelChain.bitcoin,
                type: BackupLabelType.addr,
                ref: 'reference $phrase',
                label: phrase,
              ),
            ],
            unattributedCount: 0,
            skippedCount: 0,
          ),
          wallets: const [],
          derivations: const [],
        ),
      );
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'}
        ..found = [backup(content: content)];
      await pump(tester);
      await tapText(tester, l10n.restoreFromBackup);
      await tapText(tester, 'Savings');
      expect(find.text(l10n.restoreFilteredFields(2)), findsOneWidget);
      expect(find.textContaining(phrase), findsNothing);
      expect(find.textContaining('reference $phrase'), findsNothing);
      await tapText(tester, l10n.restore);
      expect(find.text(l10n.restoreFilteredFields(2)), findsOneWidget);
      expect(find.textContaining(phrase), findsNothing);
    });

    /// Drives the UI to the result screen of a backup with one apply.
    Future<void> restoreOnce(WidgetTester tester) async {
      repository
        ..destination = BackupDestination.googleDrive
        ..included = {'g'}
        ..found = [backup()];
      await pump(tester);
      await tapText(tester, l10n.restoreFromBackup);
      await tapText(tester, 'Savings');
      await tapText(tester, l10n.restore);
    }

    testWidgets(
      'retrying recomputes the plan and applies again: two effective calls',
      (tester) async {
        labels.failApply = true;
        secrets.report = _secretsReport(added: 2);
        await restoreOnce(tester);

        // The first apply: Secrets wrote, Labels failed.
        expect(secrets.restored, hasLength(1));
        expect(labels.applies, 1);
        expect(find.text(l10n.restorePartial), findsOneWidget);
        expect(find.text(l10n.restoreLabelsFailed), findsOneWidget);
        expect(find.text(l10n.registryRestored(2)), findsOneWidget);

        // The user retries from the result: the plan is recomputed, both owners
        // are asked again, and this time it completes.
        labels.failApply = false;
        await tapText(tester, l10n.retryRestore);
        expect(labels.previews, 2, reason: 'the plan is recomputed');
        expect(secrets.restored, hasLength(2));
        expect(labels.applies, 2);
        expect(find.text(l10n.labelsRestored), findsOneWidget);
        expect(find.text(l10n.retryRestore), findsNothing);
      },
    );

    testWidgets(
      'a failed Secrets step is its own warning, never a failed freeze',
      (tester) async {
        secrets.failRestore = true;
        await restoreOnce(tester);

        expect(find.text(l10n.restorePartial), findsOneWidget);
        expect(find.text(l10n.restoreSecretsFailed), findsOneWidget);
        expect(find.text(l10n.freezeFailed(1)), findsNothing);
        expect(find.text(l10n.freezePending(1)), findsNothing);
        // A generic retry, not the freezes one.
        expect(find.text(l10n.retryRestore), findsOneWidget);
        expect(find.text(l10n.retryFreezes), findsNothing);
        // Labels did succeed and are reported as such.
        expect(find.text(l10n.restoredAmounts(3, 0)), findsOneWidget);
      },
    );

    testWidgets(
      'a refused BIP85 list never ends on the complete success screen',
      (tester) async {
        secrets.report = _secretsReport(refused: true);
        await restoreOnce(tester);

        expect(find.text(l10n.labelsRestored), findsNothing);
        expect(find.text(l10n.restorePartial), findsOneWidget);
        expect(find.text(l10n.restoreRegistryRefused), findsOneWidget);
        expect(find.text(l10n.retryRestore), findsOneWidget);
      },
    );

    testWidgets('ignored secret-shaped fields make the result partial', (
      tester,
    ) async {
      excludedInFile = 3;
      await restoreOnce(tester);
      expect(find.text(l10n.restorePartial), findsOneWidget);
      expect(find.text(l10n.restoreFilteredFields(3)), findsOneWidget);
      expect(find.text(l10n.labelsRestored), findsNothing);
    });

    testWidgets('a report is never published after the session ended', (
      tester,
    ) async {
      labels.onApply = () => secrets.reopen();
      secrets.report = _secretsReport(added: 2);
      await restoreOnce(tester);

      expect(labels.applies, 1);
      expect(find.text(l10n.labelsRestored), findsNothing);
      expect(find.text(l10n.restorePartial), findsNothing);
      expect(find.text(l10n.failureScopeChanged), findsOneWidget);
    });

    testWidgets('a complete restore reports what was written', (tester) async {
      secrets.report = _secretsReport(added: 4, labels: 1);
      await restoreOnce(tester);

      expect(find.text(l10n.labelsRestored), findsOneWidget);
      expect(find.text(l10n.registryRestored(4)), findsOneWidget);
      expect(find.text(l10n.walletsRestored(1)), findsOneWidget);
      expect(find.text(l10n.retryRestore), findsNothing);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  testWidgets('the journey is translated in French', (tester) async {
    await pump(tester, locale: const Locale('fr'));
    final fr = lookupBackupMetadataLocalizations(const Locale('fr'));
    expect(find.text(fr.continueAction), findsOneWidget);
    expect(find.text(fr.restoreFromBackup), findsOneWidget);
    expect(fr.confirmTitle, isNot(l10n.confirmTitle));
    expect(fr.restoreSecretsFailed, isNot(l10n.restoreSecretsFailed));
  });

  test('the entry shows the real status, not a fixed word', () {
    String label(BackupSummary summary) =>
        backupSummaryLabel(l10n, summary, 'en');
    expect(label(BackupSummary.off), l10n.off);
    expect(label(const BackupSummary(enabled: true)), l10n.statusOn);
    final at = DateTime.utc(2026, 11, 1, 12);
    expect(
      label(BackupSummary(enabled: true, lastDurableBackup: at)),
      startsWith('Up to date'),
    );
    expect(l10n.off, isNot(l10n.statusOn));
  });
}
