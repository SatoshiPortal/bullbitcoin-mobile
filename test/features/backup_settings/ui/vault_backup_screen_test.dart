import 'dart:typed_data';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/features/backup_settings/data/vault_backup_test_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/publish_vault_descriptor_backups_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/verify_vault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_backup_screen.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bullvault/bullvault_test_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

class _Parser extends Fake implements BitcoinDescriptorPort {
  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);
}

void main() {
  late VaultBackupTestRepositoryImpl history;
  late VaultBackupCubit cubit;
  late _Metadata metadata;
  late _Vaults vaults;
  final record = testBullVaultCreateResult().record;
  final codec = testBullVaultRecoveryPackageCodec();

  setUpAll(() => registerFallbackValue(VaultBackupDestination.nostr));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    vaults = _Vaults();
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));
    // Neither remote descriptor route can answer for this vault, so a check
    // has three honest results and no date to record.
    when(() => vaults.encodePrivateDescriptorBackup(any())).thenAnswer(
      (_) async => const Err<BullVaultDescriptorBackup, BullVaultFailure>(
        BullVaultInvalidRecoveryFailure(),
      ),
    );
    when(
      () => vaults.verifyNostrDescriptorBackup(
        any(),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async => const Ok<NostrDescriptorVerification, BullVaultFailure>((
        found: false,
        incomplete: true,
      )),
    );
    when(
      () => vaults.recordDescriptorPublicationVerified(
        walletId: any(named: 'walletId'),
        destination: any(named: 'destination'),
      ),
    ).thenAnswer((_) async => const Ok<void, BullVaultFailure>(null));
    when(
      () => vaults.encodeRecoveryPackage(record.recoveryPackage),
    ).thenReturn(codec.encode(record.recoveryPackage));
    // No destination was ever chosen for this vault.
    when(() => vaults.descriptorPublications(any())).thenAnswer(
      (_) async =>
          const Ok<List<VaultDescriptorPublication>, BullVaultFailure>([]),
    );
    history = VaultBackupTestRepositoryImpl();
    metadata = _Metadata();
    // The server holds no backup for this seed: an honest "no remote copy".
    when(metadata.fetchRemoteContents).thenAnswer(
      (_) async => const Ok<WalletBackupContents?, WalletBackupFailure>(null),
    );
    when(
      metadata.serverOrigin,
    ).thenAnswer((_) async => 'https://backup.example');
    cubit = VaultBackupCubit(
      VerifyVaultDescriptorBackupUsecase(
        vaults,
        metadata,
        _Parser(),
        history,
        _Files(),
      ),
      PublishVaultDescriptorBackupsUsecase(vaults, metadata),
      record.walletId,
    );
    await cubit.load();
  });

  tearDown(() => cubit.close());

  Future<BuildContext> pump(WidgetTester tester, AppThemeType theme) async {
    // The whole list must build: the status rows sit below a 600px viewport.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(theme),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const VaultBackupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(VaultBackupScreen));
  }

  test('checking a backup keeps the publication rows it had', () async {
    when(() => vaults.descriptorPublications(record.walletId)).thenAnswer(
      (_) async => Ok<List<VaultDescriptorPublication>, BullVaultFailure>([
        VaultDescriptorPublication(
          walletId: record.walletId,
          destination: VaultBackupDestination.server,
          enabled: true,
          artifact: Uint8List.fromList(const [1, 2, 3]),
          artifactSha256: 'a' * 64,
          state: VaultPublicationState.failed,
          attempts: 1,
          updatedAt: DateTime.utc(2027),
        ),
      ]),
    );
    await cubit.load();
    expect(cubit.state.hasOutstandingPublication, isTrue);

    await cubit.checkAgain();

    expect(
      cubit.state.hasOutstandingPublication,
      isTrue,
      reason: 'a check says nothing about what was published where',
    );
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('bitcoin reads coming soon, never untested (${theme.name})', (
      tester,
    ) async {
      final context = await pump(tester, theme);
      final rows = tester
          .widgetList<BackupTestStatusRow>(find.byType(BackupTestStatusRow))
          .toList();
      expect(rows, hasLength(VaultBackupSource.values.length));
      final bitcoin = rows.singleWhere(
        (row) => row.label == context.loc.bullVaultTestBitcoin,
      );
      expect(bitcoin.unavailable, isTrue);
      expect(bitcoin.testedAt, isNull);
      expect(
        rows.where((row) => row.unavailable),
        hasLength(1),
        reason: 'Only the deferred on-chain destination is unavailable',
      );

      expect(find.text(context.loc.backupSettingsComingSoon), findsOneWidget);
      final status = tester.widget<Text>(
        find.text(context.loc.backupSettingsComingSoon),
      );
      expect(status.style!.color, context.appColors.onSurfaceVariant);
      expect(status.style!.color, isNot(context.appColors.error));
      expect(status.style!.color, isNot(context.appColors.success));
      // Every other source still reports honestly.
      expect(
        find.text(context.loc.backupSettingsNotTested),
        findsNWidgets(VaultBackupSource.values.length - 1),
      );
    });
  }

  testWidgets('a vault this phone kept no seed for offers no words', (
    tester,
  ) async {
    final foreign = testBullVaultCreateResult(usesBullMobile: false).record;
    expect(foreign.mobileSeedFingerprint, isNull);
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([foreign]));
    when(
      () => vaults.encodeRecoveryPackage(foreign.recoveryPackage),
    ).thenReturn(codec.encode(foreign.recoveryPackage));
    await cubit.load();

    final context = await pump(tester, AppThemeType.light);

    expect(find.text(context.loc.backupWordsEntry), findsNothing);
    expect(
      find.text(context.loc.bullVaultExportDescriptor),
      findsOneWidget,
      reason: 'every other recovery action is still offered',
    );
  });

  testWidgets('check again never records an on-chain test date', (
    tester,
  ) async {
    final context = await pump(tester, AppThemeType.light);
    await tester.tap(find.text(context.loc.bullVaultCheckAgain));
    // The button spins while busy, so settle by state rather than by animation.
    for (var i = 0; i < 20 && cubit.state.busy; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(cubit.state.busy, isFalse);
    expect(
      cubit.state.checkedSource,
      isNull,
      reason: 'every remote source was checked, not one',
    );
    expect(cubit.state.latest.keys, {
      VaultBackupSource.metadata,
      VaultBackupSource.bip138,
      VaultBackupSource.nostr,
    });
    final policy = record.recoveryPackage.policy;
    final dates =
        await history.load(
              VaultBackupTest.identity(policy.descriptor, policy.network.name),
              endpoint: 'https://backup.example',
            )
            as Ok<Map<VaultBackupSource, DateTime>, dynamic>;
    expect(dates.value, isEmpty);
  });

  testWidgets('a failed check shows beside the date, never as one', (
    tester,
  ) async {
    final context = await pump(tester, AppThemeType.light);
    await tester.tap(find.text(context.loc.bullVaultCheckAgain));
    for (var i = 0; i < 20 && cubit.state.busy; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    final rows = tester
        .widgetList<BackupTestStatusRow>(find.byType(BackupTestStatusRow))
        .toList();
    String? noteFor(String label) =>
        rows.singleWhere((row) => row.label == label).latestAttempt;
    expect(
      noteFor(context.loc.bullVaultTestMetadata),
      context.loc.bullVaultCheckLatestFailed,
    );
    expect(
      noteFor(context.loc.bullVaultTestBip138),
      context.loc.bullVaultCheckLatestUnavailable,
    );
    expect(
      noteFor(context.loc.bullVaultTestNostr),
      context.loc.bullVaultCheckLatestIncomplete,
    );
    expect(noteFor(context.loc.bullVaultTestManual), isNull);
    expect(noteFor(context.loc.bullVaultTestBitcoin), isNull);
    // A failed attempt never becomes a tested date.
    expect(
      find.text(context.loc.backupSettingsNotTested),
      findsNWidgets(VaultBackupSource.values.length - 1),
    );
    expect(find.text(context.loc.backupSettingsTested), findsNothing);
  });
}
