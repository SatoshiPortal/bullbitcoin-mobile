import 'dart:async';

import 'package:bb_mobile/core/seed/domain/usecases/ensure_canonical_seed_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_cosigner_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_privacy/screen_privacy.dart';

class _Vaults extends Mock implements BullVaultRepository {}

class _Wallets extends Mock implements GetWalletUsecase {}

class _Seeds extends Mock implements EnsureCanonicalSeedUsecase {}

class _Ownership extends Mock implements WalletSignerOwnershipPort {}

class _Unlock extends AppUnlockFacade {
  @override
  Widget buildReauthenticationGate({
    required ValueChanged<AppUnlockGrant> onSuccess,
    bool canPop = false,
  }) {
    final gate =
        super.buildReauthenticationGate(onSuccess: onSuccess, canPop: canPop)
            as PinCodeUnlockScreen;
    return Scaffold(
      body: TextButton(
        onPressed: gate.onSuccess,
        child: const Text('Authenticate fixture'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final loc = AppLocalizationsEn();
  late _Vaults vaults;
  late _Wallets wallets;
  late _Seeds seeds;
  late _Ownership ownership;
  Completer<bool>? protection;

  setUp(() {
    vaults = _Vaults();
    wallets = _Wallets();
    seeds = _Seeds();
    ownership = _Ownership();
    protection = null;
    ScreenCaptureProtection.instance.enabledByUser = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'screenshotOff' && protection != null) {
            return protection!.future;
          }
          return true;
        });
  });
  tearDown(() {
    ScreenCaptureProtection.instance.enabledByUser = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open fixture'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => BullVaultCosignerCubit(
                      ImportBullVaultCosignerUsecase(
                        vaults,
                        wallets,
                        seeds,
                        ownership,
                      ),
                    ),
                    child: BullVaultCosignerScreen(
                      walletId: 'fixture',
                      appUnlock: _Unlock(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
  }

  void noPrivateWork() {
    verifyZeroInteractions(vaults);
    verifyZeroInteractions(wallets);
    verifyZeroInteractions(seeds);
    verifyZeroInteractions(ownership);
  }

  testWidgets('cancel before entering a key makes no private reads or writes', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(loc.bullVaultCosignerStored), findsOneWidget);
    expect(find.byType(BullInputText), findsNothing);
    await tester.tap(find.text(loc.cancelButton));
    await tester.pumpAndSettle();
    expect(find.text('Open fixture'), findsOneWidget);
    noPrivateWork();
  });

  testWidgets('disabled capture protection never exposes the key form', (
    tester,
  ) async {
    ScreenCaptureProtection.instance.enabledByUser = false;
    await open(tester);
    await tester.tap(find.text(loc.bullVaultCosignerContinue));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyUnavailableNotice), findsOneWidget);
    expect(find.byType(BullInputText), findsNothing);
    expect(find.text('Authenticate fixture'), findsNothing);
    noPrivateWork();
  });

  testWidgets(
    'capture and authentication precede entry; background clears both fields',
    (tester) async {
      protection = Completer<bool>();
      await open(tester);
      await tester.tap(find.text(loc.bullVaultCosignerContinue));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BullInputText), findsNothing);
      expect(find.text('Authenticate fixture'), findsNothing);
      protection!.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(BullInputText), findsNothing);
      await tester.tap(find.text('Authenticate fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(BullInputText), findsNWidgets(2));
      expect(find.text(loc.passphraseLabel), findsOneWidget);
      expect(
        find.text(loc.bullVaultRestoreMobilePassphraseLabel),
        findsNothing,
      );
      await tester.enterText(
        find.byType(TextField).first,
        'public fixture input',
      );
      await tester.enterText(find.byType(TextField).last, 'fixture passphrase');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(BullInputText), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Authenticate fixture'), findsOneWidget);
      expect(find.byType(BullInputText), findsNothing);
      await tester.tap(find.text('Authenticate fixture'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BullInputText>(find.byType(BullInputText))
            .map((input) => input.value),
        everyElement(''),
      );
      noPrivateWork();
    },
  );
}
