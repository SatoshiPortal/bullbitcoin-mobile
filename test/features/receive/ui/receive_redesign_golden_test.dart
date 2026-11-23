@Tags(['golden'])
library;

import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_amount_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, ScriptType;
import 'package:swaps/swaps.dart';

class _Receive extends Mock implements ReceiveBloc {}

const _invoice =
    'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq'
    'dq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2aw'
    'hz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';

Wallet _wallet({
  String name = 'Savings',
  bool liquid = false,
  bool empty = false,
  SignerDevice? hardware,
}) => Wallet(
  origin: name,
  label: name,
  network: liquid ? Network.liquidMainnet : Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: hardware == null ? SignerEntity.local : SignerEntity.remote,
  signerDevice: hardware,
  balanceSat: empty ? BigInt.zero : BigInt.from(100000),
);

ReceiveState _state(String name) {
  final lightning = name.startsWith('lightning');
  final liquid = name == 'liquid' || lightning;
  final wallet = _wallet(
    liquid: liquid,
    empty: name == 'advanced-empty',
    hardware: name == 'advanced-ledger'
        ? SignerDevice.ledgerNanoX
        : name == 'advanced-bitbox'
        ? SignerDevice.bitbox02
        : null,
  );
  final date = DateTime.utc(2026, 11, 19);
  final address = WalletAddress(
    walletId: wallet.id,
    index: 0,
    address: liquid
        ? 'VJLDwNs1NRv92ccqPmx5S12ht9yP2TJtySBi2ZvKKPiKTtqEghkD8RsWnEnj4PqUGFvSk8Yc3CwB8KBC'
        : 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
    createdAt: date,
    updatedAt: date,
  );
  final amount = name == 'bitcoin-amount'
      ? 25000
      : name == 'lightning-below-min'
      ? 500
      : lightning
      ? (name == 'lightning-valid' ? 25000 : 250000)
      : 0;
  final swap = Swap.lnReceive(
    id: 'public-swap-1234',
    keyIndex: 0,
    type: SwapType.lightningToLiquid,
    status: SwapStatus.pending,
    environment: SwapEnvironment.mainnet,
    creationTime: date,
    receiveWalletId: wallet.id,
    receiveAddress: address.address,
    invoice: _invoice,
    fees: const SwapFees(
      boltzPercent: 0.5,
      claimFee: 40,
      serverNetworkFees: 10,
    ),
  ) as LnReceiveSwap;
  return ReceiveState(
    type: lightning
        ? ReceiveType.lightning
        : liquid
        ? ReceiveType.liquid
        : ReceiveType.bitcoin,
    wallet: wallet,
    wallets: [
      wallet,
      if (name == 'advanced-two-wallets') _wallet(name: 'Spending'),
    ],
    walletAdmitted: true,
    payjoinAttemptSettled: true,
    payjoinGloballyEnabled: true,
    bitcoinUnit: BitcoinUnit.sats,
    inputAmountCurrencyCode: 'sats',
    inputAmount: amount == 0 ? '' : '$amount',
    confirmedAmountSat: amount == 0 ? null : amount,
    fiatCurrencyCode: 'CAD',
    fiatCurrencyCodes: const ['CAD'],
    exchangeRate: 125000,
    amountQuotes: {
      SupportedCurrency.cad: BitcoinPrice(
        currency: SupportedCurrency.cad,
        fiatAmount: 125000,
        fetchedAt: date,
      ),
    },
    bitcoinAddress: liquid ? null : address,
    liquidAddress: liquid ? address : null,
    swapLimits: lightning ? const SwapLimits(min: 1000, max: 1000000) : null,
    swapRoute: lightning ? SwapRoute.boltz : null,
    lightningSwap: (name == 'lightning-invoice' || name == 'lightning-fees')
        ? swap
        : null,
    note:
        name == 'bitcoin-amount' ||
            (name == 'lightning-invoice' || name == 'lightning-fees')
        ? 'Coffee'
        : '',
    confirmedNote: (name == 'lightning-invoice' || name == 'lightning-fees')
        ? 'Coffee'
        : '',
  );
}

class _Frame extends StatelessWidget {
  const _Frame({required this.state, required this.screen});
  final ReceiveState state;
  final Widget screen;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      forceMaterialTransparency: true,
      automaticallyImplyLeading: false,
      flexibleSpace: BullTopBar(title: 'Receive', onBack: () {}),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BullSegmented(
            items: state.type == ReceiveType.liquid
                ? {'Liquid', 'Lightning'}
                : {'Bitcoin', 'Lightning'},
            initialValue: state.isLightning
                ? 'Lightning'
                : state.type == ReceiveType.liquid
                ? 'Liquid'
                : 'Bitcoin',
            onSelected: (_) {},
          ),
        ),
        Expanded(child: screen),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final name in [
      'bitcoin-empty',
      'bitcoin-amount',
      'advanced-one-wallet',
      'advanced-two-wallets',
      'advanced-empty',
      'advanced-ledger',
      'advanced-bitbox',
      'liquid',
      'lightning-valid',
      'lightning-below-min',
      'lightning-invoice',
      'lightning-fees',
      'enlarged-qr',
    ]) {
      testWidgets('$name ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Device.screen = const Size(390, 844);
        final state = _state(name);
        final bloc = _Receive();
        when(() => bloc.state).thenReturn(state);
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => bloc.isClosed).thenReturn(false);
        when(() => bloc.fetchDistinctLabels()).thenAnswer((_) async => {});
        final amountStep =
            name == 'lightning-valid' || name == 'lightning-below-min';
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('receive-golden'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData(theme),
              localizationsDelegates: const [
                bullUiLocalizationsDelegate,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => BullAmountScope(
                snapshot: const BullAmountSnapshot(
                  unit: BitcoinUnit.sats,
                  hideAmounts: false,
                  isReady: true,
                  defaultCurrencyCode: 'CAD',
                ),
                writeUnit: (_) async => true,
                writeInputMode: (_) async => true,
                child: child ?? const SizedBox.shrink(),
              ),
              home: BlocProvider<ReceiveBloc>.value(
                value: bloc,
                child: _Frame(
                  state: state,
                  screen: amountStep
                      ? const ReceiveAmountScreen()
                      : const ReceiveQrPage(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (name.startsWith('advanced')) {
          await tester.tap(find.text('Advanced settings'));
          await tester.pumpAndSettle();
        } else if (name == 'enlarged-qr') {
          await tester.tap(find.byType(BullQrCode).first);
          await tester.pumpAndSettle();
        } else if (name == 'lightning-fees') {
          await tester.tap(find.text('Fees'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(ReceiveLnFeesDetails),
              matching: find.text('1,300 sats'),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('receive-golden')),
          matchesGoldenFile(
            '../../../goldens/receive-redesign-$name-${theme.name}.png',
          ),
        );
      });
    }
  }
}
