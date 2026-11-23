import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swaps/swaps.dart';

class _Receive extends Mock implements ReceiveBloc {}

void main() {
  testWidgets('total fee includes the percentage and equals amount minus net', (
    tester,
  ) async {
    // Published BOLT11 vector: 2500u = 250000 sats.
    const invoice =
        'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq'
        'dq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2aw'
        'hz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';
    final swap = Swap.lnReceive(
      id: 'fee-regression',
      keyIndex: 0,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: SwapEnvironment.mainnet,
      creationTime: DateTime.utc(2026),
      receiveWalletId: 'liquid',
      receiveAddress: 'public-address',
      invoice: invoice,
      fees: const SwapFees(
        boltzPercent: 0.5,
        claimFee: 40,
        serverNetworkFees: 10,
      ),
    ) as LnReceiveSwap;
    expect(swap.amountSat, 250000);
    expect(swap.receieveAmount, 248700);
    final bloc = _Receive();
    when(() => bloc.state).thenReturn(
      ReceiveState(type: ReceiveType.lightning, lightningSwap: swap),
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
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: const Scaffold(body: ReceiveLnFeesDetails()),
        ),
      ),
    );
    final displayed = tester.widget<BullAmount>(find.byType(BullAmount).first);
    expect(displayed.magnitude.value.toInt(), 1300);
    expect(
      displayed.magnitude.value.toInt(),
      swap.amountSat - (swap.receieveAmount ?? 0),
    );
  });
}
