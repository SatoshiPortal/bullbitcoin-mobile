import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadWallets extends Mock implements LoadWalletsForNetworkUsecase {}

class _MockGetMnemonic extends Mock
    implements GetMnemonicFromFingerprintUsecase {}

class _MockVerifyBackup extends Mock implements VerifyPhysicalBackupUsecase {}

class _MockCompleteBackup extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

void main() {
  setUp(() => Device.screen = const Size(800, 600));
  for (final verifying in [false, true]) {
    testWidgets(
      '${verifying ? 'verification' : 'display'} does not retain another wallet mnemonic',
      (tester) async {
        const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => true,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final previousScreen = Device.screen;
        Device.screen = const Size(800, 600);
        addTearDown(() => Device.screen = previousScreen);
        final first = _localWallet('11111111');
        final second = _localWallet('22222222');
        final firstWords = Completer<(List<String>, String?)>();
        final secondWords = Completer<(List<String>, String?)>();
        final load = _MockLoadWallets();
        final mnemonic = _MockGetMnemonic();
        when(load.execute).thenAnswer((_) async => [first, second]);
        when(
          () => mnemonic.execute('11111111'),
        ).thenAnswer((_) => firstWords.future);
        when(
          () => mnemonic.execute('22222222'),
        ).thenAnswer((_) => secondWords.future);
        final bloc = TestWalletBackupBloc(
          loadWalletsForNetworkUsecase: load,
          getMnemonicFromFingerprintUsecase: mnemonic,
          verifyPhysicalBackupUsecase: _MockVerifyBackup(),
          completePhysicalBackupVerificationUsecase: _MockCompleteBackup(),
        );
        addTearDown(bloc.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: bloc,
            child: MaterialApp(
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: verifying
                  ? VerifyMnemonicScreen(onVerified: () {})
                  : const ShowMnemonicScreen(),
            ),
          ),
        );
        bloc.add(const LoadWallets(fingerprint: '11111111'));
        await tester.pump();
        await tester.pump();
        if (!verifying) {
          firstWords.complete((const ['abandon', 'ability', 'able'], null));
          await tester.pumpAndSettle();
          expect(find.text('abandon'), findsOneWidget);
        }

        bloc.add(WalletSelected(wallet: second));
        await tester.pump();
        await tester.pump();
        expect(find.text('abandon'), findsNothing);
        secondWords.complete((const ['legal', 'winner', 'thank'], null));
        await tester.pumpAndSettle();
        expect(find.text('legal'), findsOneWidget);
        if (verifying) {
          firstWords.complete((const ['abandon', 'ability', 'able'], null));
          await tester.pumpAndSettle();
          expect(find.text('legal'), findsOneWidget);
          expect(find.text('abandon'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('displays and verifies the local seed of a descriptor wallet', (
    tester,
  ) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    const fingerprint = 'beef1234';
    const words = [
      'legal',
      'winner',
      'thank',
      'year',
      'wave',
      'sausage',
      'worth',
      'useful',
      'legal',
      'winner',
      'thank',
      'yellow',
    ];
    final wallet = Wallet(
      origin: 'vault',
      label: 'Vault',
      network: Network.bitcoinMainnet,
      publicDescriptor: 'wsh(multi(2,xpub-mobile/<0;1>/*,xpub-cold/<0;1>/*))',
      signers: [
        WalletSigner.single(
          masterFingerprint: '11111111',
          xpubFingerprint: '',
          xpub: 'xpub-mobile',
          signer: SignerEntity.local,
          signerDevice: null,
        ).copyWith(localSeedFingerprint: fingerprint),
        WalletSigner.single(
          id: 'cold',
          descriptorKeyId: 'cold-key',
          masterFingerprint: '22222222',
          xpubFingerprint: '',
          xpub: 'xpub-cold',
          signer: SignerEntity.remote,
          signerDevice: null,
        ),
      ],
      scriptType: null,
      balanceSat: BigInt.zero,
    );
    final load = _MockLoadWallets();
    final mnemonic = _MockGetMnemonic();
    final verifyBackup = _MockVerifyBackup();
    final complete = _MockCompleteBackup();
    when(load.execute).thenAnswer((_) async => [wallet]);
    when(
      () => mnemonic.execute(fingerprint),
    ).thenAnswer((_) async => (words, null));
    when(
      () => verifyBackup.execute(fingerprint: fingerprint, mnemonic: words),
    ).thenAnswer((_) async => true);
    when(
      () => complete.execute(fingerprint: fingerprint),
    ).thenAnswer((_) async {});
    final bloc = TestWalletBackupBloc(
      loadWalletsForNetworkUsecase: load,
      getMnemonicFromFingerprintUsecase: mnemonic,
      verifyPhysicalBackupUsecase: verifyBackup,
      completePhysicalBackupVerificationUsecase: complete,
    );
    addTearDown(bloc.close);
    Device.screen = const Size(800, 600);
    Widget app(Widget screen) => BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    );
    await tester.pumpWidget(app(const ShowMnemonicScreen()));
    bloc.add(const LoadWallets(fingerprint: fingerprint));
    await tester.pumpAndSettle();
    expect(find.text('yellow'), findsOneWidget);

    var verified = false;
    await tester.pumpWidget(
      app(VerifyMnemonicScreen(onVerified: () => verified = true)),
    );
    await tester.pumpAndSettle();
    for (final word in words) {
      final tile = find
          .widgetWithText(InkWell, word)
          .evaluate()
          .firstWhere((element) => (element.widget as InkWell).onTap != null);
      final finder = find.byWidget(tile.widget);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    expect(verified, isTrue);
    verify(() => complete.execute(fingerprint: fingerprint)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Wallet _localWallet(String fingerprint) => Wallet(
  origin: fingerprint,
  network: Network.bitcoinMainnet,
  publicDescriptor: 'public-descriptor',
  signers: [
    WalletSigner.single(
      masterFingerprint: fingerprint,
      xpubFingerprint: '',
      xpub: 'public-key',
      signer: SignerEntity.local,
      signerDevice: null,
    ).copyWith(localSeedFingerprint: fingerprint),
  ],
  scriptType: null,
  balanceSat: BigInt.zero,
);
