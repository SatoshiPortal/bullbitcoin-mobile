import 'dart:typed_data';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/publish_vault_descriptor_backups_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_destinations_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_destinations_screen.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bull_ui/bull_ui.dart' show BullCheckbox;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

void main() {
  const walletId = 'vault-fixture';
  final loc = AppLocalizationsEn();
  late _Vaults vaults;
  late _Metadata metadata;
  late List<VaultDescriptorPublication> rows;
  late VaultDestinationsCubit cubit;

  VaultDescriptorPublication row(
    VaultBackupDestination destination, {
    required bool enabled,
    VaultPublicationState state = VaultPublicationState.idle,
    bool prepared = false,
  }) => VaultDescriptorPublication(
    walletId: walletId,
    destination: destination,
    enabled: enabled,
    artifact: prepared ? Uint8List.fromList(const [1, 2, 3]) : null,
    artifactSha256: prepared ? 'a' * 64 : null,
    state: state,
    attempts: 0,
    updatedAt: DateTime.utc(2027),
  );

  setUpAll(() => registerFallbackValue(VaultBackupDestination.server));

  setUp(() {
    vaults = _Vaults();
    metadata = _Metadata();
    rows = [];
    when(
      () => vaults.descriptorPublications(walletId),
    ).thenAnswer((_) async => Ok(rows));
    when(
      () => vaults.setDescriptorBackupDestination(
        walletId: any(named: 'walletId'),
        destination: any(named: 'destination'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((call) async {
      final destination =
          call.namedArguments[#destination] as VaultBackupDestination;
      final enabled = call.namedArguments[#enabled] as bool;
      rows = [
        ...rows.where((existing) => existing.destination != destination),
        row(destination, enabled: enabled),
      ];
      return const Ok<void, BullVaultFailure>(null);
    });
    when(
      () => vaults.recordDescriptorPublicationSent(
        walletId: any(named: 'walletId'),
        destination: any(named: 'destination'),
        accepted: any(named: 'accepted'),
      ),
    ).thenAnswer((_) async => const Ok<void, BullVaultFailure>(null));
    when(() => metadata.watchState()).thenAnswer(
      (_) => Stream.value(
        Ok(
          WalletBackupState(
            enabled: false,
            localRevision: 0,
            uploadedRevision: 0,
            lastSucceededAt: null,
            unsupportedVersion: null,
          ),
        ),
      ),
    );
    cubit = VaultDestinationsCubit(
      PublishVaultDescriptorBackupsUsecase(vaults, metadata),
      WatchWalletBackupUsecase(metadata),
      walletId,
    );
    addTearDown(cubit.close);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider.value(
          value: cubit,
          child: const VaultDestinationsScreen(),
        ),
      ),
    );
    await cubit.load();
    await tester.pumpAndSettle();
  }

  testWidgets('every destination starts unchecked and bitcoin is inert', (
    tester,
  ) async {
    await open(tester);

    final boxes = tester
        .widgetList<BullCheckbox>(find.byType(BullCheckbox))
        .toList();
    expect(boxes, hasLength(3));
    expect(boxes.map((box) => box.checked), everyElement(isFalse));
    expect(boxes.last.onChanged, isNull);
    expect(find.text(loc.backupSettingsComingSoon), findsOneWidget);
    expect(find.text(loc.vaultDestinationsRecommended), findsOneWidget);
    verifyNever(
      () => vaults.setDescriptorBackupDestination(
        walletId: walletId,
        destination: VaultBackupDestination.server,
        enabled: true,
      ),
    );
  });

  testWidgets('the relay destination says whose words seal the copy', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(loc.vaultDestinationsNostrDescription), findsOneWidget);
    expect(
      loc.vaultDestinationsNostrDescription,
      contains('magic backup words'),
      reason: 'a vault recovered here publishes under this phone\'s words',
    );
  });

  testWidgets('choosing the server records the choice and keeps it', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byType(BullCheckbox).first);
    await tester.pumpAndSettle();

    verify(
      () => vaults.setDescriptorBackupDestination(
        walletId: walletId,
        destination: VaultBackupDestination.server,
        enabled: true,
      ),
    ).called(1);
    expect(
      tester.widgetList<BullCheckbox>(find.byType(BullCheckbox)).first.checked,
      isTrue,
    );
  });

  testWidgets('continue with nothing selected publishes nothing', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text(loc.continueButton));
    await tester.pumpAndSettle();

    verifyNever(() => vaults.prepareServerDescriptorBackup(any()));
    verifyNever(() => vaults.publishDescriptorToNostr(any()));
  });

  testWidgets('a destination that failed shows its result and offers a retry', (
    tester,
  ) async {
    rows = [
      row(
        VaultBackupDestination.server,
        enabled: true,
        state: VaultPublicationState.failed,
        prepared: true,
      ),
      row(VaultBackupDestination.nostr, enabled: false),
    ];
    when(
      () => vaults.prepareServerDescriptorBackup(walletId),
    ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));

    await open(tester);
    await tester.tap(find.text(loc.continueButton));
    await tester.pumpAndSettle();

    expect(find.text(loc.vaultDestinationsFailed), findsOneWidget);
    expect(find.text(loc.vaultDestinationsNotSelected), findsOneWidget);
    expect(find.text(loc.retry), findsOneWidget);
    expect(find.text(loc.backupSettingsComingSoon), findsOneWidget);
  });
}
