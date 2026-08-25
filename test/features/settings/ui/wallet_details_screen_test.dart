import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockWalletDetailsCubit extends Mock implements WalletDetailsCubit {}

Wallet _wallet({required bool isDefault}) => Wallet(
  origin: 'wallet-id',
  label: 'Savings',
  network: Network.bitcoinMainnet,
  isDefault: isDefault,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'abcd1234',
      xpubFingerprint: 'abcd1234',
      xpub: 'xpub-test',
      derivationPath: "m/84'/0'/0'",
      descriptorPath: '/<0;1>/*',
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh([abcd1234/84h/0h/0h]xpub-test/<0;1>/*)',
  balanceSat: BigInt.zero,
);

Future<void> _pumpScreen(WidgetTester tester, {required bool isDefault}) async {
  final walletBloc = _MockWalletBloc();
  final state = WalletState(
    status: WalletStatus.success,
    wallets: [_wallet(isDefault: isDefault)],
  );
  when(() => walletBloc.state).thenReturn(state);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  final walletDetailsCubit = _MockWalletDetailsCubit();
  when(() => walletDetailsCubit.state).thenReturn(const WalletDetailsState());
  when(() => walletDetailsCubit.stream).thenAnswer((_) => const Stream.empty());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: walletBloc),
        BlocProvider<WalletDetailsCubit>.value(value: walletDetailsCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WalletDetailsScreen(walletId: 'wallet-id'),
      ),
    ),
  );
}

void main() {
  testWidgets('shows wallet information directly and ends with Addresses', (
    tester,
  ) async {
    await _pumpScreen(tester, isDefault: false);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('abcd1234'), findsOneWidget);
    expect(find.text('xpub-test'), findsOneWidget);
    expect(find.text('Addresses'), findsOneWidget);
  });

  testWidgets('only offers wallet deletion for a non-default wallet', (
    tester,
  ) async {
    await _pumpScreen(tester, isDefault: true);
    expect(find.byType(BullIcon), findsNothing);

    await _pumpScreen(tester, isDefault: false);
    expect(find.byType(BullIcon), findsOneWidget);
  });
}
