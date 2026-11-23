import 'package:secrets/testing.dart';
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:primitives/primitives.dart' show BitcoinNetwork, LiquidNetwork;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';

import 'dart:async';

import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:receive/receive.dart';
import 'package:receive/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:swap_feature/testing.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Sats, ScriptType;

class _Receive extends Mock implements ReceiveBloc {}

class _Transfer extends Mock implements TransferBloc {}

class _Settings extends Mock implements SettingsCubit {}

SwapWallet _swapWallet(bool liquid) => SwapWallet(
  walletRegistrationForTesting(
    id: liquid ? 'liquid' : 'bitcoin',
    network: liquid ? LiquidNetwork.mainnet : BitcoinNetwork.mainnet,
    isDefault: false,
    signer: WalletSigner.local,
  ),
  BigInt.from(1250000),
  false,
);

Wallet _wallet(bool liquid) => Wallet(
  origin: liquid ? 'liquid' : 'bitcoin',
  network: liquid ? Network.liquidMainnet : Network.bitcoinMainnet,
  xpubFingerprint: liquid ? '11111111' : '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1250000),
);

void main() {
  final at = DateTime.utc(2026, 11, 19, 14, 32);
  final quotes = {
    SupportedCurrency.cad: BitcoinPrice(
      currency: SupportedCurrency.cad,
      fiatAmount: 125000,
      fetchedAt: at,
    ),
  };
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final name in ['receive-fiat', 'receive-qr', 'swap']) {
      testWidgets('$name ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Device.screen = const Size(390, 844);
        final wallet = _wallet(false);
        final swapBitcoin = _swapWallet(false);
        final swapLiquid = _swapWallet(true);
        final receive = _Receive();
        final transfer = _Transfer();
        final settings = _Settings();
        final fiat = name == 'receive-fiat';
        final receiveWallet = ReceiveWallet(
          id: wallet.id,
          network: wallet.network.shared,
          signsLocally: wallet.signsLocally,
          scriptType: wallet.scriptType,
          balanceSat: wallet.balanceSat,
          label: wallet.label,
        );
        when(() => receive.state).thenReturn(
          ReceiveState(
            wallet: receiveWallet,
            wallets: [receiveWallet],
            walletAdmitted: true,
            type: ReceiveType.bitcoin,
            bitcoinUnit: BitcoinUnit.sats,
            inputAmountCurrencyCode: 'sats',
            inputAmount: '10000',
            fiatCurrencyCode: 'CAD',
            amountQuotes: quotes,
            confirmedAmountSat: 10000,
            confirmedConversion: ReceiveAmountConversion(
              enteredText: '12.50',
              currencyCode: 'CAD',
              rate: 125000,
              quotedAt: at,
              sats: Sats.fromInt(10000),
            ),
          ),
        );
        when(() => receive.stream).thenAnswer((_) => const Stream.empty());
        when(() => transfer.state).thenReturn(
          TransferState(
            wallets: [swapBitcoin, swapLiquid],
            fromWallet: swapLiquid,
            toWallet: swapBitcoin,
            bitcoinUnit: BitcoinUnit.sats,
            amount: '25000',
            amountQuotes: quotes,
            fiatCurrencyCode: 'CAD',
            exchangeRate: 125000,
            maxAmountSat: 1249580,
          ),
        );
        when(() => transfer.stream).thenAnswer((_) => const Stream.empty());
        when(() => settings.state).thenReturn(
          const SettingsState(
            storedSettings: SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              hideAmounts: false,
            ),
          ),
        );
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        final Widget screen = switch (name) {
          'receive-fiat' => const Scaffold(body: ReceiveAmountScreen()),
          'receive-qr' => const Scaffold(
            body: Center(child: ReceiveInfoDetails()),
          ),
          _ => const SwapPage(),
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('golden'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData(theme),
              localizationsDelegates: const [
                bullUiLocalizationsDelegate,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<ReceiveBloc>.value(value: receive),
                  BlocProvider<TransferBloc>.value(value: transfer),
                  BlocProvider<SettingsCubit>.value(value: settings),
                ],
                child: BullAmountScope(
                  snapshot: BullAmountSnapshot(
                    unit: BitcoinUnit.sats,
                    hideAmounts: false,
                    isReady: true,
                    defaultCurrencyCode: 'CAD',
                    startInFiat: fiat,
                  ),
                  writeUnit: (_) async => true,
                  writeInputMode: (_) async => true,
                  child: screen,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final images = <ImageProvider<Object>>{
          ...tester
              .widgetList<Image>(find.byType(Image))
              .map((widget) => widget.image),
          ...tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .map((decoration) => decoration.image?.image)
              .whereType<ImageProvider<Object>>(),
        };
        final context = tester.element(find.byType(Scaffold).first);
        await tester.runAsync(() async {
          await Future.wait(
            images.map((image) => precacheImage(image, context)),
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('golden')),
          matchesGoldenFile('goldens/flow-$name-${theme.name}.png'),
        );
      });
    }
  }
}
