import 'dart:convert';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:novlang/novlang.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/setup.dart';
import 'package:preferences/preferences.dart' show Language;
import 'package:primitives/primitives.dart';
import 'package:wallet_import/wallet_import.dart';

class _Import extends Mock implements ImportFeature {}

void main() {
  testWidgets('loading splash keeps Apple wording without starting a wallet', (
    tester,
  ) async {
    var commands = 0;
    final feature = _mount(
      create: () async {
        commands++;
        return const Ok(null);
      },
      recover:
          ({
            required mnemonicWords,
            required language,
            required passphrase,
          }) async {
            commands++;
            return const Ok(null);
          },
      ready: (_) => fail('Loading must not complete onboarding'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: [
          NovlangOnboardingLocalizationsDelegate(
            resolveNovlangPolicy(TargetPlatform.iOS, false),
          ),
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(builder: feature.buildLoadingSplash),
      ),
    );
    expect(find.textContaining('Bitcoin-only services'), findsOneWidget);
    expect(find.text('Create New Wallet'), findsNothing);
    expect(commands, 0);
  });

  testWidgets('mounted recovery invokes wallet-ready exactly once', (
    tester,
  ) async {
    const privacy = MethodChannel('com.flutterplaza.no_screenshot_methods');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(privacy, (_) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(privacy, null));
    var recovered = 0;
    var ready = 0;
    final feature = _mount(
      create: () async => fail('Unexpected wallet creation'),
      recover:
          ({
            required mnemonicWords,
            required language,
            required passphrase,
          }) async {
            recovered++;
            expect(mnemonicWords, ['word']);
            expect(passphrase, isEmpty);
            return const Ok(null);
          },
      ready: (context) {
        ready++;
        context.go('/ready');
      },
    );
    final router = GoRouter(
      initialLocation: OnboardingNavigation.physicalRecoveryPath,
      routes: [
        feature.route,
        GoRoute(
          path: '/ready',
          builder: (_, _) => const Scaffold(body: Text('Wallet ready')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          OnboardingLocalizations.delegate,
          MnemonicEntryLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    final entry = tester.widget<MnemonicWidget>(find.byType(MnemonicWidget));
    entry.onSubmit((
      words: const ['word'],
      label: '',
      passphrase: '',
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Wallet ready'), findsOneWidget);
    expect(recovered, 1);
    expect(ready, 1);
  });
}

OnboardingFeature _mount({
  required CreateOnboardingWallet create,
  required RecoverOnboardingWallet recover,
  required void Function(BuildContext) ready,
}) {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
    ),
  );
  return OnboardingFeature.mount(
    createWallet: create,
    recoverWallet: recover,
    walletImport: _Import(),
    onWalletReady: ready,
    languageOf: (_) => Language.unitedStatesEnglish,
    changeLanguage: (_, _) {},
    logo: const SizedBox.shrink(),
    background: image,
    encryptedBackupIcon: image,
    physicalBackupIcon: image,
  );
}
