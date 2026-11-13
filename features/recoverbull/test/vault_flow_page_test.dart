import 'dart:async';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/derive_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/list_drive_vaults_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/read_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/delete_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/export_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_cubit.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_presentation.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_flow_page.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

const _channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

Widget app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
  supportedLocales: RecoverBullLocalizations.supportedLocales,
  home: child,
);

VaultFlowPresentation flow({
  DeriveVaultKeyUsecase? localKey,
  BackupMetadataRepository? metadata,
}) => VaultFlowPresentation(
  VaultFlowCubit(
    ManageBackupSettingsUsecase(
      metadata,
      const RecoverBullStorageFullFailure(),
    ),
    (
      pick: PickVaultUsecase(_Files()),
      list: ListDriveVaultsUsecase(_Drive()),
      select: ReadDriveVaultUsecase(_Drive()),
      delete: DeleteDriveVaultUsecase(_Drive()),
      export: ExportDriveVaultUsecase(_Files(), _Drive()),
    ),
    null,
    CompleteVaultUsecase(
      TestVaultUsecase(_Vaults(), _Wallets()),
      RestoreVaultUsecase(_Vaults(), _Wallets()),
      null,
      null,
    ),
    unavailable: const RecoverBullStorageFullFailure(),
    localKey: localKey,
    vault: EncryptedVault(
      id: '11' * 32,
      salt: '22' * 16,
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    ),
  ),
  const Ok(BitcoinNetwork.testnet),
  null,
);

void main() {
  setUp(() => ScreenCaptureProtection.instance.enabledByUser = true);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  for (final mode in ['pending', 'refused', 'throws']) {
    testWidgets(
      'password and manual key input wait for effective protection: $mode',
      (tester) async {
        final pending = Completer<bool>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (call) async {
            if (call.method != 'screenshotOff') return true;
            if (mode == 'pending') return pending.future;
            if (mode == 'throws') throw PlatformException(code: 'unavailable');
            return false;
          },
        );
        final presentation = flow();
        await tester.pumpWidget(
          app(
            VaultFlowPage(
              flow: RecoverBullFlow.recoverVault,
              presentation: () async => presentation,
              copiedMessage: 'Copied',
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(BullInputText), findsNothing);
        expect(find.textContaining('phone storage is full'), findsOneWidget);
        expect(find.text('Enter a vault key instead'), findsOneWidget);
        await tester.pumpWidget(app(const SizedBox.shrink()));
        if (!pending.isCompleted) pending.complete(true);
        await tester.pump();
        expect(presentation.cubit.isClosed, isTrue);
      },
    );
  }

  testWidgets(
    'privacy retry reveals inputs without hiding nonsecret controls',
    (tester) async {
      var protected = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (call) async => call.method != 'screenshotOff' || protected,
      );
      await tester.pumpWidget(
        app(
          VaultFlowPage(
            flow: RecoverBullFlow.recoverVault,
            presentation: () async => flow(),
            copiedMessage: 'Copied',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BullInputText), findsNothing);
      expect(find.textContaining('phone storage is full'), findsOneWidget);
      expect(find.text('Enter a vault key instead'), findsOneWidget);
      expect(tester.takeException(), isNull);

      protected = true;
      await tester.tap(find.widgetWithText(BullButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(BullInputText), findsOneWidget);
      expect(find.textContaining('phone storage is full'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      await tester.pumpAndSettle();
    },
  );

  for (final hasSettings in [false, true]) {
    testWidgets(
      'local key viewing can replace the file without contacting the server: $hasSettings',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (_) async => true,
        );
        await tester.pumpWidget(
          app(
            VaultFlowPage(
              flow: RecoverBullFlow.viewVaultKey,
              presentation: () async => flow(
                localKey: DeriveVaultKeyUsecase(_LocalVaults()),
                metadata: hasSettings ? _Metadata() : null,
              ),
              copiedMessage: 'Copied',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(BullInputText), findsNothing);
        expect(find.text('Use server instead'), findsOneWidget);
        expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
        await tester.ensureVisible(
          find.widgetWithText(BullButton, 'Vault Key'),
        );
        await tester.tap(find.widgetWithText(BullButton, 'Vault Key'));
        await tester.pumpAndSettle();
        expect(find.textContaining('No wallet on this device'), findsOneWidget);
        expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
        final localizations = RecoverBullLocalizations.of(
          tester.element(find.byType(VaultFlowPage)),
        );
        final picker = find.widgetWithText(
          BullButton,
          localizations.recoverbullSelectCustomLocationProvider,
        );
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(BullButton, 'Vault Key'),
        );
        await tester.tap(find.widgetWithText(BullButton, 'Vault Key'));
        await tester.pumpAndSettle();
        expect(find.text('*' * 64), findsOneWidget);
        expect(find.text('11' * 32), findsNothing);
        await tester.pumpWidget(app(const SizedBox.shrink()));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('late initialization after route close disposes the flow', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => true,
    );
    final pending = Completer<VaultFlowPresentation>();
    final presentation = flow();
    await tester.pumpWidget(
      app(
        VaultFlowPage(
          flow: RecoverBullFlow.recoverVault,
          presentation: () => pending.future,
          copiedMessage: 'Copied',
        ),
      ),
    );
    await tester.pumpWidget(app(const SizedBox.shrink()));
    pending.complete(presentation);
    await tester.pump();
    expect(presentation.cubit.isClosed, isTrue);
  });
}

final class _Files extends Fake implements VaultFileRepository {
  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> pick() async => Ok(
    EncryptedVault(
      id: '33' * 32,
      salt: '22' * 16,
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    ),
  );
}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Vaults extends Fake implements VaultRepository {}

final class _Wallets extends Fake implements RecoverBullWalletPort {}

final class _LocalVaults extends Fake implements VaultRepository {
  @override
  Future<Result<VaultKey, RecoverBullFailure>> deriveKey(
    EncryptedVault vault,
  ) async => vault.id == '11' * 32
      ? const Err(VaultLocalKeyMismatchFailure())
      : Ok(VaultKey('11' * 32));
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async => Ok(
    BackupSettings(
      server: Uri.parse('http://backup-example.onion'),
      permissionGranted: true,
      monitoringEnabled: false,
      generation: 0,
    ),
  );
}
