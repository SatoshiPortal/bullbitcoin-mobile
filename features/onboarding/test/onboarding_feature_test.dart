import 'dart:convert';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:novlang/novlang.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/domain/onboarding_operations.dart';
import 'package:onboarding/src/onboarding_feature.dart';
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
    // The store delegate loads asynchronously, and the loading spinner never
    // settles. Pump a second frame instead of waiting for all animations.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Bitcoin-only services'), findsOneWidget);
    expect(find.text('Create New Wallet'), findsNothing);
    expect(commands, 0);
  });

  testWidgets('loading splash renders the injected loadingLogo, not the logo', (
    tester,
  ) async {
    final feature = _mount(
      create: () async => fail('Loading must not create a wallet'),
      recover: ({
        required mnemonicWords,
        required language,
        required passphrase,
      }) async => fail('Loading must not recover a wallet'),
      ready: (_) => fail('Loading must not complete onboarding'),
      logo: const Text('INJECTED_LOGO'),
      loadingLogo: const Text('INJECTED_LOADING_LOGO'),
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('INJECTED_LOADING_LOGO'), findsOneWidget);
    expect(find.text('INJECTED_LOGO'), findsNothing);
    expect(_camoImage, findsOneWidget);
    // The injected red/grid background is the create/recover screen's, and
    // the loading page must not paint it.
    expect(_injectedBackground, findsNothing);
  });

  testWidgets('the loading splash keeps the wrapper the host injects', (
    tester,
  ) async {
    var taps = 0;
    final feature = _mount(
      create: () async => fail('Loading must not create a wallet'),
      recover: ({
        required mnemonicWords,
        required language,
        required passphrase,
      }) async => fail('Loading must not recover a wallet'),
      ready: (_) => fail('Loading must not complete onboarding'),
      loadingLogo: _UnlockerStub(onTap: () => taps++),
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
    await tester.pump(const Duration(milliseconds: 100));

    // The host's affordance is not replaced, hidden or wrapped offstage: the
    // V3 mark is its visible child and the gesture still reaches it.
    expect(find.byType(_UnlockerStub), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(_UnlockerStub),
        matching: find.byType(SplashMark),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(SplashMark));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('loading splash falls back to the V3 mark', (tester) async {
    final feature = _mount(
      create: () async => fail('Loading must not create a wallet'),
      recover: ({
        required mnemonicWords,
        required language,
        required passphrase,
      }) async => fail('Loading must not recover a wallet'),
      ready: (_) => fail('Loading must not complete onboarding'),
      logo: const Text('INJECTED_LOGO'),
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SplashMark), findsOneWidget);
    expect(find.text('INJECTED_LOGO'), findsNothing);
    expect(_camoImage, findsOneWidget);
  });

  testWidgets('the create/recover screen keeps the injected logo', (
    tester,
  ) async {
    final feature = _mount(
      create: () async => fail('Unexpected wallet creation'),
      recover: ({
        required mnemonicWords,
        required language,
        required passphrase,
      }) async => fail('Unexpected wallet recovery'),
      ready: (_) => fail('Unexpected wallet-ready'),
      logo: const Text('INJECTED_LOGO'),
    );
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [feature.route],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          OnboardingLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('INJECTED_LOGO'), findsOneWidget);
    expect(find.byType(SplashMark), findsNothing);
    expect(_camoImage, findsNothing);
    expect(_injectedBackground, findsOneWidget);
    expect(find.text('Create New Wallet'), findsOneWidget);
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

/// Stands in for the host's tap-to-unlock wrapper: a tappable that keeps the
/// injected child visible. The point of the test is that the seam forwards the
/// wrapper unchanged, not that this particular widget exists.
class _UnlockerStub extends StatelessWidget {
  const _UnlockerStub({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 127 * 2975 / 2512,
        height: 127,
        child: SplashMark(),
      ),
    );
  }
}

OnboardingFeature _mount({
  required CreateOnboardingWallet create,
  required RecoverOnboardingWallet recover,
  required void Function(BuildContext) ready,
  Widget logo = const SizedBox.shrink(),
  Widget? loadingLogo,
}) {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
    ),
  );
  return mountOnboardingRoutes(
    createWallet: create,
    recoverWallet: recover,
    walletImport: _Import(),
    onWalletReady: ready,
    languageOf: (_) => Language.unitedStatesEnglish,
    changeLanguage: (_, _) {},
    logo: logo,
    loadingLogo: loadingLogo,
    background: _injectedImage,
    encryptedBackupIcon: image,
    physicalBackupIcon: image,
  );
}

final _injectedImage = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
  ),
);

/// The camo backdrop of the loading splash.
final _camoImage = find.byWidgetPredicate(
  (Widget widget) => switch (widget) {
    Image(image: AssetImage(:final assetName, :final package)) =>
      assetName == 'assets/splash/splash_camo.png' && package == 'onboarding',
    _ => false,
  },
  description: 'the loading splash camo backdrop',
);

/// The background injected by the host for the create/recover screen.
final _injectedBackground = find.byWidgetPredicate(
  (Widget widget) => switch (widget) {
    Image(image: MemoryImage()) => true,
    _ => false,
  },
  description: 'the injected create/recover background',
);
