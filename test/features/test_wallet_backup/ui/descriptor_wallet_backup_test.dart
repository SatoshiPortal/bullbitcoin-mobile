import 'package:secrets/secrets.dart';
import '../../bullvault/bullvault_secrets_fixture.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
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
    implements GetSecretFromFingerprintUsecase {}

class _MockCompleteBackup extends Mock
    implements CompleteBackupVerificationUsecase {}

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
    final fixture = BullVaultSecretsFixture();
    final secret = await tester.runAsync(() => fixture.mnemonic(words));
    if (secret == null) fail('Secret creation did not complete');
    final fingerprint = secret.id.hex;
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
    final complete = _MockCompleteBackup();
    when(load.execute).thenAnswer((_) async => Ok([wallet]));
    when(
      () => mnemonic.execute(fingerprint),
    ).thenAnswer((_) async => Ok(secret));
    when(
      () => complete.execute(fingerprint: fingerprint),
    ).thenAnswer((_) async => const Ok(null));
    final bloc = TestWalletBackupBloc(
      loadWalletsForNetworkUsecase: load,
      getSecretFromFingerprintUsecase: mnemonic,
      completeBackupVerificationUsecase: complete,
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
    Future<void> settleSecret() async {
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        if (i >= 2 &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(app(const ShowMnemonicScreen()));
    bloc.add(LoadWallets(fingerprint: fingerprint));
    await tester.pump();
    await settleSecret();
    expect(find.byType(MnemonicView), findsOneWidget);
    expect(find.text('yellow'), findsNothing);

    var verified = false;
    await tester.pumpWidget(
      app(VerifyMnemonicScreen(onVerified: () => verified = true)),
    );
    await settleSecret();
    final challenge = tester.widget<MnemonicChallenge>(
      find.byType(MnemonicChallenge),
    );
    challenge.onSolved();
    await tester.pumpAndSettle();
    expect(verified, isTrue);
    verify(() => complete.execute(fingerprint: fingerprint)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
