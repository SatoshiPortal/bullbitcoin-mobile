import 'package:bb_mobile/features/settings/domain/usecases/discover_wallet_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/wallet_discovery_cubit.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show WalletFacade;
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

Wallet _wallet({required bool isDefault}) => Wallet(
  origin: 'wallet-id',
  label: 'Savings',
  network: Network.bitcoinMainnet,
  isDefault: isDefault,
  masterFingerprint: 'abcd1234',
  xpubFingerprint: 'abcd1234',
  scriptType: ScriptType.bip84,
  xpub: 'xpub-test',
  externalPublicDescriptor: 'wpkh(xpub-test/0/*)',
  internalPublicDescriptor: 'wpkh(xpub-test/1/*)',
  signer: SignerEntity.local,
  signerDevice: null,
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

  await tester.pumpWidget(
    BlocProvider<WalletBloc>.value(
      value: walletBloc,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => WalletDiscoveryCubit(
            DiscoverWalletUsecase(
              WalletFacade(
                const Stream.empty(),
                discoverWallet: (_) async => const Ok(null),
              ),
            ),
          ),
          child: const WalletDetailsScreen(walletId: 'wallet-id'),
        ),
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
    await tester.scrollUntilVisible(find.text('Addresses'), 100);
    expect(find.text('Scan for missing transactions'), findsOneWidget);
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
