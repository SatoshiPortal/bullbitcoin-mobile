import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadWalletsForNetworkUsecase extends Mock
    implements LoadWalletsForNetworkUsecase {}

class _MockGetMnemonicFromFingerprintUsecase extends Mock
    implements GetMnemonicFromFingerprintUsecase {}

class _MockVerifyPhysicalBackupUsecase extends Mock
    implements VerifyPhysicalBackupUsecase {}

class _MockCompleteBackupVerificationUsecase extends Mock
    implements CompleteBackupVerificationUsecase {}

const _privacyChannel = MethodChannel('com.flutterplaza.no_screenshot_methods');
const _fingerprint = 'abcd1234';
const _words = [
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
  'yes',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, null);
  });

  testWidgets('loads verification words when wallets arrive after opening', (
    tester,
  ) async {
    final wallets = Completer<Result<List<Wallet>, TestWalletBackupFailure>>();
    final loadWallets = _MockLoadWalletsForNetworkUsecase();
    final getMnemonic = _MockGetMnemonicFromFingerprintUsecase();
    when(() => loadWallets.execute()).thenAnswer((_) => wallets.future);
    when(
      () => getMnemonic.execute(_fingerprint),
    ).thenAnswer((_) async => const Ok((_words, null)));
    final bloc = TestWalletBackupBloc(
      loadWalletsForNetworkUsecase: loadWallets,
      getMnemonicFromFingerprintUsecase: getMnemonic,
      verifyPhysicalBackupUsecase: _MockVerifyPhysicalBackupUsecase(),
      completeBackupVerificationUsecase:
          _MockCompleteBackupVerificationUsecase(),
    )..add(const LoadWallets());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const VerifyMnemonicScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verifyNever(() => getMnemonic.execute(_fingerprint));

    wallets.complete(
      Ok([
        Wallet(
          origin: 'test-wallet',
          label: 'Test',
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
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(bloc.state.selectedWallet, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('sausage'), findsOneWidget);
    expect(find.text('legal'), findsNWidgets(2));
    verify(() => getMnemonic.execute(_fingerprint)).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
