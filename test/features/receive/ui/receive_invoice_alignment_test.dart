import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:swaps/swaps.dart';

class _Receive extends Mock implements ReceiveBloc {}

const _invoice =
    'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq'
    'dq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2aw'
    'hz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';

Future<void> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final swap = Swap.lnReceive(
    id: 'public-swap-1234',
    keyIndex: 0,
    type: SwapType.lightningToLiquid,
    status: SwapStatus.pending,
    environment: SwapEnvironment.mainnet,
    creationTime: DateTime.utc(2026),
    receiveWalletId: 'liquid',
    invoice: _invoice,
    fees: const SwapFees(
      boltzPercent: 0.5,
      claimFee: 40,
      serverNetworkFees: 10,
    ),
  ) as LnReceiveSwap;
  final bloc = _Receive();
  when(() => bloc.state).thenReturn(
    ReceiveState(
      type: ReceiveType.lightning,
      lightningSwap: swap,
      confirmedNote: 'Coffee',
    ),
  );
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
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
        ),
        writeUnit: (_) async => true,
        child: child!,
      ),
      home: BlocProvider<ReceiveBloc>.value(
        value: bloc,
        child: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ReceiveLnInfoDetails(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('invoice values share the same edge with an inset action slot', (
    tester,
  ) async {
    await _mount(tester);
    final values = find.byType(CurrencyText);
    expect(values, findsNWidgets(3));
    final right = tester.getTopRight(values.first).dx;
    expect(tester.getTopRight(values.at(1)).dx, right);
    expect(tester.getTopRight(values.at(2)).dx, right);
    expect(tester.getTopRight(find.text('Coffee')).dx, right);
    final actionRight = tester.getTopRight(find.byType(BullFieldAction)).dx;
    expect(actionRight, 366);
    expect(right, actionRight - 56);
  });

  testWidgets('fees sheet has a close action and single-line muted labels', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.text('Fees'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Server network fees'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.style?.fontSize, 14);
    final identifier = tester.widget<Text>(find.text('public-swap-1234'));
    expect(identifier.maxLines, 1);
    expect(identifier.overflow, TextOverflow.ellipsis);
    final sheetValues = find.descendant(
      of: find.byType(ReceiveLnFeesDetails),
      matching: find.byType(CurrencyText),
    );
    for (final element in sheetValues.evaluate()) {
      expect(tester.getTopRight(find.byWidget(element.widget)).dx, 310);
    }
    expect(tester.getTopRight(find.byTooltip('Copy')).dx, 366);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiveLnFeesDetails), findsNothing);
  });
}
