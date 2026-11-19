import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
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
import 'package:bull_recoverbull/src/ui/pages/password_input_page.dart';
import 'package:bull_recoverbull/src/ui/recoverbull_flow_navigator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

const _channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

Widget app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  localizationsDelegates: RecoverBullFeature.localizationsDelegates,
  supportedLocales: RecoverBullLocalizations.supportedLocales,
  home: child,
);

/// Lays pages out on a phone-sized screen (Pixel 5), as on a device.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

/// The recovery password screen of [presentation]'s flow.
Widget recovery(VaultFlowPresentation presentation) => app(
  RecoverBullFlowHost(
    flow: RecoverBullFlow.recoverVault,
    presentation: presentation,
    page: const PasswordInputPage(),
    copiedMessage: 'Copied',
    onTestVault: () {},
    onFinished: () {},
  ),
);

/// The new-backup PIN screen of [presentation]'s flow.
Widget secure(VaultFlowPresentation presentation) => app(
  RecoverBullFlowHost(
    flow: RecoverBullFlow.secureVault,
    presentation: presentation,
    page: const PasswordInputPage(),
    copiedMessage: 'Copied',
    onTestVault: () {},
    onFinished: () {},
  ),
);

VaultFlowPresentation flow({
  VaultRepository? vaults,
  RecoverBullWalletPort? wallets,
  BackupMetadataRepository? metadata,
  AttemptMonitoringRepository? monitoring,
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
      metadata,
      monitoring,
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

  for (final warning in [true, false]) {
    testWidgets('recovery callback acknowledges accounting warning: $warning', (
      tester,
    ) async {
      usePhoneScreen(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (_) async => true,
      );
      final vaults = _PassphraseVaults();
      final wallets = _RecoveryWallets();
      final presentation = flow(
        vaults: vaults,
        wallets: wallets,
        metadata: warning ? null : _Metadata(),
        monitoring: warning ? null : _Monitoring(),
      );
      var recovered = 0;
      await tester.pumpWidget(
        app(
          RecoverBullFlowHost(
            flow: RecoverBullFlow.recoverVault,
            presentation: presentation,
            page: const PasswordInputPage(),
            copiedMessage: 'Copied',
            onTestVault: () {},
            onFinished: () {},
            onRecovered: () => recovered++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(BullButton, 'Enter a vault key instead'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '33' * 32);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'correct');
      await tester.ensureVisible(find.text('Verify'));
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(vaults.imported, 1);
      expect(wallets.restores, 1);
      expect(
        presentation.cubit.state.completion?.recovery,
        isA<VaultRecovered>(),
      );
      final l10n = await RecoverBullLocalizations.delegate.load(
        const Locale('en'),
      );
      if (warning) {
        expect(recovered, 0);
        expect(find.text(l10n.recoverbullJournalUnavailable), findsOneWidget);
        await tester.ensureVisible(find.text(l10n.recoverbullGotIt));
        await tester.tap(find.text(l10n.recoverbullGotIt));
        await tester.pumpAndSettle();
      } else {
        expect(find.text(l10n.recoverbullGotIt), findsNothing);
      }
      expect(recovered, 1);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      await presentation.close();
    });
  }

  for (final mode in ['pending', 'refused', 'throws']) {
    testWidgets(
      'password and manual key input wait for effective protection: $mode',
      (tester) async {
        usePhoneScreen(tester);
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
        await tester.pumpWidget(recovery(presentation));
        await tester.pump();
        await tester.pump();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Enter a vault key instead'), findsOneWidget);
        await tester.pumpWidget(app(const SizedBox.shrink()));
        if (!pending.isCompleted) pending.complete(true);
        await tester.pump();
        await presentation.close();
      },
    );
  }

  testWidgets(
    'privacy retry reveals inputs without hiding nonsecret controls',
    (tester) async {
      usePhoneScreen(tester);
      var protected = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (call) async => call.method != 'screenshotOff' || protected,
      );
      await tester.pumpWidget(recovery(flow()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Enter a vault key instead'), findsOneWidget);
      expect(tester.takeException(), isNull);

      protected = true;
      await tester.tap(find.widgetWithText(BullButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Enter a vault key instead'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('late initialization after route close disposes the flow', (
    tester,
  ) async {
    usePhoneScreen(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => true,
    );
    final pending = Completer<VaultFlowPresentation>();
    final presentation = flow();
    await tester.pumpWidget(
      app(
        RecoverBullFlowNavigator(
          flow: RecoverBullFlow.recoverVault,
          presentation: () => pending.future,
          copiedMessage: 'Copied',
          onTestVault: () {},
          onFinished: () {},
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
    usePhoneScreen(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => true,
    );
    await tester.pumpWidget(recovery(flow()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(BullButton, 'Enter a vault key instead'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-a-key');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Wrong password for this backup file'), findsOneWidget);
    // Let the snack bar dismiss itself before the tree is torn down.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('a new backup refuses a short or common PIN', (tester) async {
    usePhoneScreen(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (_) async => true,
    );
    await tester.pumpWidget(secure(flow()));
    await tester.pumpAndSettle();

    Future<void> submit(String pin) async {
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byIcon(Icons.backspace_outlined).first);
      }
      for (final digit in pin.split('')) {
        await tester.tap(
          find.descendant(
            of: find.byType(BullPinPad),
            matching: find.text(digit),
          ),
        );
      }
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await submit('12345');
    expect(
      find.text('Password must be at least 6 characters long'),
      findsOneWidget,
    );
    await submit('123456');
    expect(
      find.text('This password is too common. Please choose a different one'),
      findsOneWidget,
    );
    await submit('482913');
    expect(find.textContaining('too common'), findsNothing);
    expect(find.textContaining('at least 6'), findsNothing);
    expect(find.text('Confirm PIN'), findsWidgets);
    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  });

  for (final proceedWithout in [false, true]) {
    testWidgets(
      'passphrase retry and explicit sibling choice: $proceedWithout',
      (tester) async {
        usePhoneScreen(tester);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (_) async => true,
        );
        final vaults = _PassphraseVaults();
        final wallets = _RecoveryWallets();
        final presentation = flow(vaults: vaults, wallets: wallets);
        await tester.pumpWidget(recovery(presentation));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(BullButton, 'Enter a vault key instead'),
        );
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

final class _Metadata extends Fake implements BackupMetadataRepository {
  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async => Ok(
    BackupSettings(
      server: Uri.parse('http://backup.onion'),
      permissionGranted: true,
      monitoringEnabled: true,
      generation: 0,
    ),
  );

  @override
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  ) async => const Ok(null);
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {
  @override
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  ) async => const Ok(null);
}
