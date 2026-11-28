import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_exchange/testing.dart' show PayinSourcePage;
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart' show BtcNetwork;
import 'package:exchange/steps.dart' show PayinFromAppWallet, PayinSource;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, LiquidNetwork, Network;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:settings/settings.dart' show Settings;
import 'package:settings/testing.dart';
import 'package:sync/sync.dart' show WalletKey;

class _MockSettingsCubit extends Mock implements SettingsCubit {}

WalletPickerCopy _copy(BuildContext context) => (
  defaultBitcoinTitle: context.loc.globalDefaultBitcoinWalletLabel,
  defaultLiquidTitle: context.loc.globalDefaultLiquidWalletLabel,
  bitcoinDescription: context.loc.walletTypeBitcoinNetwork,
  liquidDescription: context.loc.walletTypeLiquidAndLightning,
  remoteDescription: context.loc.walletTypeWatchSigner,
  watchOnlyDescription: context.loc.walletTypeWatchOnly,
  unavailableLabel: context.loc.walletLoadFailed,
  silentTitle: context.loc.walletSpTitle,
  silentDescription: context.loc.walletSpExperimental,
);

WalletPickerRow _row(
  String origin,
  Network network, {
  String? label,
  bool isDefault = false,
  WalletSigner signer = WalletSigner.local,
  int? balanceSat = 0,
  bool isSyncing = false,
}) => (
  selection: (
    key: WalletKey(id: '$origin:regtest', network: network),
    label: label,
    isDefault: isDefault,
  ),
  signer: signer,
  origin: origin,
  balanceSat: balanceSat,
  isSyncing: isSyncing,
);

Future<void> _pump(WidgetTester tester, WidgetBuilder build) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final settings = _MockSettingsCubit();
  when(() => settings.stream).thenAnswer((_) => const Stream.empty());
  when(() => settings.state).thenReturn(
    const SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        hideAmounts: true,
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        ...appLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settings),
          BitcoinPriceFixture.prices(),
        ],
        child: Settings.amountScope(
          navigatorKey: navigatorKey,
          child: Scaffold(body: Builder(builder: build)),
        ),
      ),
    ),
  );
}

void main() {
  final bitcoin = _row(
    'bitcoin',
    BitcoinNetwork.regtest,
    label: 'Stored default label',
    isDefault: true,
    isSyncing: true,
  );
  final liquid = _row('liquid', LiquidNetwork.regtest, isDefault: true);
  final unavailable = _row(
    'savings',
    BitcoinNetwork.regtest,
    label: 'Savings',
    balanceSat: null,
  );
  final remote = _row(
    'remote',
    BitcoinNetwork.regtest,
    signer: WalletSigner.remote,
  );
  final watch = _row('watch', LiquidNetwork.regtest, signer: WalletSigner.none);
  final imported = _row('another-import', LiquidNetwork.regtest);
  final rows = [remote, unavailable, liquid, watch, imported, bitcoin];

  testWidgets('Home orders defaults first and keeps imports in input order', (
    tester,
  ) async {
    final selections = <OverviewWalletSelection>[];
    await _pump(
      tester,
      (context) => WalletPicker(
        rows: rows,
        copy: _copy(context),
        onSelected: selections.add,
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(WalletPicker)));
    final cards = tester
        .widget<WalletCardList>(find.byType(WalletCardList))
        .rows;
    expect(cards.map((row) => row.title), [
      l10n.globalDefaultBitcoinWalletLabel,
      l10n.globalDefaultLiquidWalletLabel,
      'remote',
      'Savings',
      'watch',
      'another-import',
    ]);
    expect(cards.map((row) => row.description), [
      l10n.walletTypeBitcoinNetwork,
      l10n.walletTypeLiquidAndLightning,
      l10n.walletTypeWatchSigner,
      l10n.walletTypeBitcoinNetwork,
      l10n.walletTypeWatchOnly,
      l10n.walletTypeLiquidAndLightning,
    ]);
    expect(cards.map((row) => row.tagColor), [
      AppColors.light.onTertiary,
      AppColors.light.tertiary,
      AppColors.light.secondary,
      AppColors.light.onTertiary,
      AppColors.light.secondary,
      AppColors.light.tertiary,
    ]);
    expect(cards.first.balanceSat, 0);
    expect(cards.first.isSyncing, isTrue);
    expect(cards[3].balanceSat, isNull);
    await tester.tap(find.text('remote'));
    expect(selections, [remote.selection]);
  });

  testWidgets('ordinary payin picker keeps local choices without balances', (
    tester,
  ) async {
    final selections = <OverviewWalletSelection>[];
    final payins = <PayinSource>[];
    var silentOpens = 0;
    await _pump(
      tester,
      (context) => PayinSourcePage(
        title: 'Pay or Sell source',
        ui: (
          walletCards: (context, onSelected) => WalletPicker.localSigners(
            rows: rows,
            copy: _copy(context),
            silent: (
              balanceSat: 9000,
              isSyncing: false,
              onOpen: () => silentOpens++,
            ),
            onSelected: (selection) {
              selections.add(selection);
              onSelected?.call(selection);
            },
          ),
          openWalletHome: (_) {},
          brandAsset: '',
          successAsset: '',
        ),
        onPicked: payins.add,
        onBack: () {},
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(WalletPicker)));
    expect(find.text('remote'), findsNothing);
    expect(find.text('watch'), findsNothing);
    expect(find.text('Stored default label'), findsNothing);
    expect(
      find.widgetWithText(ListTile, l10n.walletLoadFailed),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.globalDefaultBitcoinWalletLabel));
    await tester.tap(find.text(l10n.globalDefaultLiquidWalletLabel));
    await tester.tap(find.text('Savings'));
    final silentTitle = find.text(l10n.walletSpTitle);
    await tester.ensureVisible(silentTitle);
    await tester.tap(silentTitle);
    expect(selections, [
      bitcoin.selection,
      liquid.selection,
      unavailable.selection,
    ]);
    expect(payins, [
      const PayinFromAppWallet(
        'bitcoin:regtest',
        BtcNetwork.bitcoin,
        label: 'Stored default label',
        isDefault: true,
      ),
      const PayinFromAppWallet(
        'liquid:regtest',
        BtcNetwork.liquid,
        isDefault: true,
      ),
      const PayinFromAppWallet(
        'savings:regtest',
        BtcNetwork.bitcoin,
        label: 'Savings',
      ),
    ]);
    expect(silentOpens, 1);
  });

  testWidgets('local picker filters defaults and returns the original label', (
    tester,
  ) async {
    final remoteDefault = _row(
      'remote-default',
      BitcoinNetwork.regtest,
      isDefault: true,
      signer: WalletSigner.remote,
    );
    final selections = <OverviewWalletSelection>[];
    await _pump(
      tester,
      (context) => WalletPicker.localSigners(
        rows: [imported, remoteDefault, liquid, bitcoin],
        copy: _copy(context),
        onSelected: selections.add,
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(WalletPicker)));
    final cards = tester.widget<WalletCardList>(find.byType(WalletCardList));
    expect(cards.rows.map((row) => row.title), [
      l10n.globalDefaultBitcoinWalletLabel,
      l10n.globalDefaultLiquidWalletLabel,
      imported.origin,
    ]);
    await tester.tap(find.text(imported.origin));
    expect(selections, [imported.selection]);
    expect(selections.single.label, isNull);
  });

  testWidgets('multiple imports retain input order across default ranking', (
    tester,
  ) async {
    final z = _row('z-import', BitcoinNetwork.regtest);
    final a = _row('a-import', LiquidNetwork.regtest);
    final m = _row('m-import', BitcoinNetwork.regtest);
    await _pump(
      tester,
      (context) =>
          WalletPicker(rows: [z, liquid, a, bitcoin, m], copy: _copy(context)),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(WalletPicker)));
    final cards = tester.widget<WalletCardList>(find.byType(WalletCardList));
    expect(cards.rows.map((row) => row.title), [
      l10n.globalDefaultBitcoinWalletLabel,
      l10n.globalDefaultLiquidWalletLabel,
      'z-import',
      'a-import',
      'm-import',
    ]);
  });

  testWidgets('Silent is independent of rows and uses the wallet card theme', (
    tester,
  ) async {
    var opens = 0;
    await _pump(
      tester,
      (context) => WalletPicker(
        rows: const [],
        copy: _copy(context),
        silent: (balanceSat: 45000, isSyncing: true, onOpen: () => opens++),
      ),
    );
    final card = tester.widget<WalletCard>(find.byType(WalletCard));
    expect(card.tagColor, AppColors.light.tertiary);
    expect(card.balanceSat, 45000);
    expect(card.isSyncing, isTrue);
    expect(find.text('** sats'), findsOneWidget);
    expect(find.text('45,000 sats'), findsNothing);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(WalletCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.light.walletCardBackground);
    await tester.tap(find.text(card.title));
    expect(opens, 1);

    await _pump(
      tester,
      (context) => WalletPicker(rows: const [], copy: _copy(context)),
    );
    expect(find.byType(WalletCard), findsNothing);
  });
}
