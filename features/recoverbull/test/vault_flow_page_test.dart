import 'dart:async';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
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
  VaultRepository? vaults,
  RecoverBullWalletPort? wallets,
}) => VaultFlowPresentation(
  VaultFlowCubit(
    const ManageBackupSettingsUsecase(null, RecoverBullStorageFullFailure()),
    (
      pick: PickVaultUsecase(_Files()),
      list: ListDriveVaultsUsecase(_Drive()),
      select: ReadDriveVaultUsecase(_Drive()),
      delete: DeleteDriveVaultUsecase(_Drive()),
      export: ExportDriveVaultUsecase(_Files(), _Drive()),
    ),
    null,
    CompleteVaultUsecase(
      TestVaultUsecase(vaults ?? _Vaults(), wallets ?? _Wallets()),
      RestoreVaultUsecase(vaults ?? _Vaults(), wallets ?? _Wallets()),
      null,
      null,
    ),
    unavailable: const RecoverBullStorageFullFailure(),
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

  testWidgets('invalid manual vault key is reported without an exception', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => true,
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
    await tester.tap(find.text('Enter a vault key instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-a-key');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Wrong password for this backup file'), findsOneWidget);
  });

  for (final proceedWithout in [false, true]) {
    testWidgets(
      'passphrase retry and explicit sibling choice: $proceedWithout',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (_) async => true,
        );
        final vaults = _PassphraseVaults();
        final wallets = _RecoveryWallets();
        final presentation = flow(vaults: vaults, wallets: wallets);
        await tester.pumpWidget(
          app(
            VaultFlowPage(
              flow: RecoverBullFlow.recoverVault,
              presentation: () async => presentation,
              copiedMessage: 'Copied',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enter a vault key instead'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '33' * 32);
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Passphrase required'), findsWidgets);
        expect(vaults.imported, 0);
        await tester.enterText(find.byType(TextField), 'incorrect');
        await tester.ensureVisible(find.text('Verify'));
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('does not match your backup'),
          findsOneWidget,
        );
        expect(vaults.imported, 0);
        if (proceedWithout) {
          await tester.ensureVisible(find.text('Continue without'));
          await tester.tap(find.text('Continue without'));
          await tester.pumpAndSettle();
          expect(find.textContaining('probably empty'), findsOneWidget);
          expect(vaults.imported, 0);
          await tester.ensureVisible(find.text('Confirm'));
          await tester.tap(find.text('Confirm'));
        } else {
          await tester.enterText(find.byType(TextField), 'correct');
          await tester.ensureVisible(find.text('Verify'));
          await tester.tap(find.text('Verify'));
        }
        await tester.pumpAndSettle();
        expect(vaults.imported, 1);
        expect(wallets.restores, 1);
        expect(vaults.lastUnverified, proceedWithout);
        expect(
          presentation.cubit.state.completion?.verifiedContext != null,
          !proceedWithout,
        );
      },
    );
  }
}

final class _Files extends Fake implements VaultFileRepository {}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Vaults extends Fake implements VaultRepository {}

final class _Wallets extends Fake implements RecoverBullWalletPort {}

final class _PassphraseVaults extends Fake implements VaultRepository {
  int imported = 0;
  bool lastUnverified = false;

  @override
  Future<Result<Fingerprint, RecoverBullFailure>> restore(
    EncryptedVault vault,
    VaultKey key, {
    String passphrase = '',
    bool allowUnverified = false,
  }) async {
    if (passphrase != 'correct' && !allowUnverified) {
      return const Err(VaultPassphraseRequiredFailure());
    }
    imported++;
    lastUnverified = allowUnverified;
    return Ok(Fingerprint('73c5da0a'));
  }
}

final class _RecoveryWallets extends Fake implements RecoverBullWalletPort {
  int restores = 0;
  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}
