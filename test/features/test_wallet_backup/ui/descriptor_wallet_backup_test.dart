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
