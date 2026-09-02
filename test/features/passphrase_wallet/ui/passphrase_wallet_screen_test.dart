// What the Passphrase page actually renders (spec 25.6, 25.7, 25.8).
//
// The Cubit suite proves the page state; this proves the card that reads it.
// Both halves are needed: the bug F20 records — a loaded wallet under a card
// still saying Locked — lived entirely in the gap between them.
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/forget_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/prepare_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/scan_passphrase_wallet_balance_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/unlock_known_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/update_passphrase_wallet_metadata_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_cubit.dart';
import 'package:bb_mobile/features/passphrase_wallet/public/passphrase_wallet_routes.dart';
import 'package:bb_mobile/features/passphrase_wallet/ui/passphrase_wallet_screen.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/public/wallet_routes.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Fingerprint, Ok;

import '../support/passphrase_wallet_harness.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

const _noScreenshotChannel = MethodChannel(
  'com.flutterplaza.no_screenshot_methods',
);

void main() {
  late FakeWalletFacade wallets;
  late KeychainManifestFacade manifest;
  late FaultInjectingManifestRepository manifestRepository;
  late FakePassphraseWalletScanner scanner;
  late PassphraseWalletCubit cubit;

  /// Puts one passphrase wallet in the manifest without loading it, which is
  /// the locked card the page shows on entry.
  Future<void> givenWallet({String? label, String? hint}) async {
    final saved = await manifest.recordWallet(
      parentFingerprint: Fingerprint(parentFingerprint),
      wallet: passphraseBinding(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
        label: label,
        hint: hint,
      ),
    );
    expect(saved, isA<Ok<bool, KeychainManifestFailure>>());
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);

    wallets = FakeWalletFacade();
    final built = buildManifest();
    manifest = built.facade;
    manifestRepository = built.repository;
    scanner = FakePassphraseWalletScanner(
      balances: {firstDescriptor: BigInt.from(1500)},
    );
    final seedAndSettings = fakeSeedAndSettings();
    final getWallets = GetPassphraseWalletsUsecase(
      seedAndSettings.seed,
      seedAndSettings.settings,
      manifest,
    );
    cubit = PassphraseWalletCubit(
      getWallets,
      PreparePassphraseWalletUsecase(
        seedAndSettings.seed,
        seedAndSettings.settings,
        getWallets,
        FakePassphraseWalletDeriver(),
      ),
      UnlockKnownPassphraseWalletUsecase(wallets),
      CreatePassphraseWalletUsecase(manifest, wallets),
      ForgetPassphraseWalletUsecase(wallets, manifest),
      UpdatePassphraseWalletMetadataUsecase(manifest, wallets),
      ScanPassphraseWalletBalanceUsecase(scanner),
      wallets,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
    await cubit.close();
    await wallets.dispose();
    await manifestRepository.dispose();
  });

  /// Loads the page, then renders it, so the card under test is the one a user
  /// reaches by opening Passphrase wallets.
  Future<void> pumpPage(WidgetTester tester, {bool hideAmounts = false}) async {
    await cubit.load();

    final settings = _MockSettingsCubit();
    when(() => settings.state).thenReturn(
      SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          hideAmounts: hideAmounts,
        ),
      ),
    );
    when(
      () => settings.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());

    final router = GoRouter(
      initialLocation: '/${PassphraseWalletRoute.wallets.path}',
      routes: [
        GoRoute(
          path: '/${PassphraseWalletRoute.wallets.path}',
          name: PassphraseWalletRoute.wallets.name,
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<PassphraseWalletCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>.value(value: settings),
            ],
            child: const PassphraseWalletScreen(),
          ),
        ),
        GoRoute(
          path: WalletRoute.walletHome.path,
          name: WalletRoute.walletHome.name,
          builder: (_, _) => const Text('home screen'),
        ),
        GoRoute(
          path: ReceiveRoute.receiveBitcoin.path,
          name: ReceiveRoute.receiveBitcoin.name,
          builder: (_, _) => const Text('receive screen'),
        ),
        GoRoute(
          path: SendRoute.send.path,
          name: SendRoute.send.name,
          builder: (_, _) => const Text('send screen'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a wallet saved without a label shows the default name', (
    tester,
  ) async {
    await givenWallet();

    await pumpPage(tester);

    expect(find.text('Passphrase Wallet'), findsOneWidget);
  });

  testWidgets('a loaded wallet reads Loaded on its card', (tester) async {
    await givenWallet(label: 'Vault');
    wallets.loadedWalletId = 'wallet-one';

    await pumpPage(tester);

    expect(find.text('Loaded'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
  });

  testWidgets('a wallet nobody unlocked reads Locked on its card', (
    tester,
  ) async {
    await givenWallet(label: 'Vault');

    await pumpPage(tester);

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Loaded'), findsNothing);
  });

  testWidgets('no action on a locked card reaches Receive or Send', (
    tester,
  ) async {
    await givenWallet(label: 'Vault', hint: 'the usual place');

    await pumpPage(tester);

    final actions = tester
        .widgetList<TextButton>(
          find.descendant(
            of: find.byType(Card),
            matching: find.byType(TextButton),
          ),
        )
        .map((button) => (button.child! as Text).data)
        .toList();
    expect(actions, [
      'Show hint',
      'Edit hint',
      'Forget passphrase wallet',
    ], reason: 'a locked card offers nothing that spends or receives');

    // Every one of them, walked: absence from the card is not enough if one of
    // the screens behind it hands the user a Receive or Send route.
    for (final action in actions) {
      await tester.tap(find.text(action!));
      await tester.pumpAndSettle();
      expect(find.text('receive screen'), findsNothing);
      expect(find.text('send screen'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the hint stays hidden until Show hint is tapped', (
    tester,
  ) async {
    await givenWallet(label: 'Vault', hint: 'the usual place');

    await pumpPage(tester);

    expect(find.text('the usual place'), findsNothing);

    await tester.tap(find.text('Show hint'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('the usual place'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Hide Balances hides the balance on a locked card', (
    tester,
  ) async {
    await givenWallet(label: 'Vault');

    await pumpPage(tester, hideAmounts: true);

    expect(find.text('1,500 sats'), findsNothing);
    expect(find.textContaining('1,500'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });

  testWidgets(
    'the balance shows on a locked card when amounts are not hidden',
    (tester) async {
      await givenWallet(label: 'Vault');

      await pumpPage(tester, hideAmounts: false);

      expect(find.text('1,500 sats'), findsOneWidget);
    },
  );
}
