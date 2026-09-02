import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

class _MockCompleteBackup extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _MockLoadWallets extends Mock implements LoadWalletsForNetworkUsecase {}

class _MockGetMnemonic extends Mock
    implements GetMnemonicFromFingerprintUsecase {}

class _MockVerifyBackup extends Mock implements VerifyPhysicalBackupUsecase {}

class _SeedableTestWalletBackupBloc extends TestWalletBackupBloc {
  _SeedableTestWalletBackupBloc({
    required super.completePhysicalBackupVerificationUsecase,
    required super.loadWalletsForNetworkUsecase,
    required super.getMnemonicFromFingerprintUsecase,
    required super.verifyPhysicalBackupUsecase,
  });

  void seed(TestWalletBackupState state) => emit(state);
}

const _fingerprint = 'abcd1234';
const _mnemonic = [
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacyChannel = MethodChannel(
    'com.flutterplaza.no_screenshot_methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, null);
  });

  for (final testCase in [
    (widget: const ShowMnemonicScreen(), title: 'Backup your wallet'),
    (widget: const VerifyMnemonicScreen(), title: 'Test your wallet backup'),
  ]) {
    testWidgets('${testCase.title} loads without a Flutter error', (
      tester,
    ) async {
      Device.screen = const Size(411, 890);
      final getMnemonic = _MockGetMnemonic();
      when(
        () => getMnemonic.execute(_fingerprint),
      ).thenAnswer((_) async => (_mnemonic, null));
      final bloc = _SeedableTestWalletBackupBloc(
        completePhysicalBackupVerificationUsecase: _MockCompleteBackup(),
        loadWalletsForNetworkUsecase: _MockLoadWallets(),
        getMnemonicFromFingerprintUsecase: getMnemonic,
        verifyPhysicalBackupUsecase: _MockVerifyBackup(),
      );
      bloc.seed(TestWalletBackupState(selectedWallet: _wallet));

      await tester.pumpWidget(
        BlocProvider<TestWalletBackupBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: testCase.widget,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(testCase.title), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('legal'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

final _wallet = Wallet(
  origin: 'test',
  label: 'Secure Bitcoin',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: _fingerprint,
  xpubFingerprint: _fingerprint,
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);
