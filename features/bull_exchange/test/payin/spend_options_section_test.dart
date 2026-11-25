import 'dart:async';
import 'dart:typed_data';

import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:bull_exchange/src/payin/ui/spend_options_section.dart';
import 'package:bull_ui/testing.dart';
import 'package:fees/fees.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync/sync.dart' show BitcoinCoin, Keychain;

const _fees = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);
const _ready = SpendOptionsReady(
  walletId: 'w1',
  fees: _fees,
  target: SpendPreviewTarget('bc1q', 20000),
  previews: BitcoinFeePreviewCache(
    fastest: BitcoinFeePreviewSlot(feeSat: 352, txSize: 141),
  ),
);
const SpendOptionsLabels _labels = (
  feePriority: 'Fee Priority',
  fastest: 'Fastest',
  networkFees: 'Network fees',
  advancedSettings: 'Advanced Settings',
  advancedOptions: 'Advanced options',
  replaceByFee: 'Replace-by-fee activated',
  selectCoins: 'Select coins manually',
  done: 'Done',
  feesUnavailable: 'Fees unavailable',
);

Future<ExchangeLocalizations> _pump(
  WidgetTester tester,
  SpendOptionsState spend,
  List<SpendOptionsEvent> events, {
  bool payjoin = false,
  Stream<SpendOptionsState>? changes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpendOptionsSection(
            spend: spend,
            changes: changes ?? const Stream.empty(),
            current: () => spend,
            labels: _labels,
            payjoinOffered: payjoin,
            amountSat: 20000,
            exchangeRate: 50000,
            fiatCurrency: 'CAD',
            onEvent: events.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return ExchangeLocalizations.of(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('the fee priority and the network fee of the payin', (
    tester,
  ) async {
    await _pump(tester, _ready, []);
    expect(find.text('Fee Priority'), findsOneWidget);
    expect(find.text('Fastest'), findsOneWidget);
    expect(find.text('Network fees'), findsOneWidget);
    expect(find.textContaining('352'), findsOneWidget);
  });

  testWidgets('the fee priority opens the shared fee sheet', (tester) async {
    final events = <SpendOptionsEvent>[];
    await _pump(tester, _ready, events);
    await tester.tap(find.text('Fastest'));
    await tester.pumpAndSettle();
    expect(find.byType(FeeOptionsModal), findsOneWidget);
    expect(events, contains(isA<SpendPresetPreviewsRequested>()));
  });

  testWidgets('a failed fee estimate says so and offers Retry, no fee', (
    tester,
  ) async {
    final events = <SpendOptionsEvent>[];
    final labels = await _pump(
      tester,
      const SpendFeesUnavailable('w1', 1),
      events,
    );
    expect(find.text('Fees unavailable'), findsOneWidget);
    expect(find.text('Network fees'), findsNothing);
    await tester.tap(find.text(labels.retry));
    expect(events.single, isA<SpendRetryPressed>());
  });

  testWidgets('the payjoin switch shows only when the order offers it', (
    tester,
  ) async {
    final events = <SpendOptionsEvent>[];
    final labels = await _pump(tester, _ready, events, payjoin: true);
    expect(find.text(labels.payjoinUseToggle), findsOneWidget);
    await tester.tap(find.byType(Switch));
    expect(
      events.single,
      isA<SpendPayjoinChanged>().having((e) => e.enabled, 'enabled', false),
    );
    await _pump(tester, _ready, []);
    expect(find.text(labels.payjoinUseToggle), findsNothing);
  });

  testWidgets('advanced options: RBF and the coin selection', (tester) async {
    final events = <SpendOptionsEvent>[];
    final changes = StreamController<SpendOptionsState>.broadcast();
    await _pump(tester, _ready, events, changes: changes.stream);
    await tester.tap(find.text('Advanced Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Replace-by-fee activated'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    expect(
      events.last,
      isA<SpendRbfChanged>().having((e) => e.enabled, 'enabled', false),
    );
    await tester.tap(find.text('Select coins manually'));
    await tester.pump();
    expect(events.last, isA<SpendCoinsRequested>());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    changes.add(_ready.copyWith(coins: const SpendCoinsUnavailable()));
    await tester.pump();
    final labels = ExchangeLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(find.text(labels.exchangePayinCoinsUnavailable), findsOneWidget);
    await changes.close();
  });

  testWidgets('the picked coins sheet shows each coin with its address', (
    tester,
  ) async {
    final changes = StreamController<SpendOptionsState>.broadcast();
    await _pump(tester, _ready, [], changes: changes.stream);
    await tester.tap(find.text('Advanced Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select coins manually'));
    await tester.pump();
    changes.add(
      _ready.copyWith(
        coins: SpendCoinsLoaded([
          BitcoinCoin(
            outpoint: (txId: 'c1', vout: 0),
            amountSat: BigInt.from(50000),
            scriptPubkey: Uint8List(0),
            address: 'tb1qcoin',
            keychain: Keychain.external,
            confirmations: 3,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final viewer = tester.widget<AddressViewer>(find.byType(AddressViewer));
    expect(viewer.data, 'tb1qcoin');
    expect(viewer.style, isNotNull);
    expect(viewer.color, isNotNull);
    final size = tester.getSize(find.byType(AddressViewer));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await changes.close();
  });

  testWidgets('external and fixed payins have nothing to choose', (
    tester,
  ) async {
    await _pump(tester, const SpendOptionsNone(), []);
    expect(find.text('Fee Priority'), findsNothing);
  });
}
