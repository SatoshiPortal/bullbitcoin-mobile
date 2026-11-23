import 'dart:async';

import 'package:rust_bindings/rust_bindings.dart' show BullSdk;

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_external_address_input.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, bullUiLocalizationsDelegate;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Transfer extends MockBloc<TransferEvent, TransferState>
    implements TransferBloc {}

Future<void> _pumpInput(WidgetTester tester, TransferBloc bloc) =>
    tester.pumpWidget(
      BlocProvider<TransferBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: [
            ...appLocalizationsDelegates,
            bullUiLocalizationsDelegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SwapExternalAddressInput()),
        ),
      ),
    );

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  testWidgets('offers named secondary Scan and Paste buttons at 48 dp', (
    tester,
  ) async {
    final bloc = _Transfer();
    whenListen(
      bloc,
      const Stream<TransferState>.empty(),
      initialState: const TransferState(),
    );
    await _pumpInput(tester, bloc);

    for (final label in ['Scan', 'Paste']) {
      final button = find.byWidgetPredicate(
        (widget) => widget is BullButton && widget.label == label,
      );
      expect(button, findsOneWidget, reason: label);
      expect(tester.getSize(button).height, 48);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await bloc.close();
  });

  testWidgets('retains the complete URI when the bloc normalizes it early', (
    tester,
  ) async {
    const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
    const raw = 'bitcoin:$address?amount=0.000025&label=Invoice';
    final states = StreamController<TransferState>();
    final bloc = _Transfer();
    whenListen(bloc, states.stream, initialState: const TransferState());
    await _pumpInput(tester, bloc);

    // Exercise the host boundary before the adapter's next validation frame:
    // the bloc may publish a normalized address as soon as it receives input.
    tester
        .widget<PaymentDestinationField>(find.byType(PaymentDestinationField))
        .onChanged(raw);
    states.add(const TransferState(externalAddress: address, amount: '2500'));
    await tester.pump();

    expect(
      tester
          .widget<PaymentDestinationField>(find.byType(PaymentDestinationField))
          .value,
      raw,
    );
    verify(() => bloc.add(const TransferEvent.externalAddressChanged(raw)))
        .called(1);

    // Later unrelated state emissions must not turn that URI into an address.
    states.add(const TransferState(externalAddress: address, amount: '2501'));
    await tester.pump();
    expect(
      tester
          .widget<PaymentDestinationField>(find.byType(PaymentDestinationField))
          .value,
      raw,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await states.close();
    await bloc.close();
  });
}
