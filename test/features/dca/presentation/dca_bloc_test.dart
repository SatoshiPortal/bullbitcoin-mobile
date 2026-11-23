import 'package:bull_exchange/testing.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStartDcaUsecase extends Mock implements StartDcaUsecase {}

class MockSetDcaUsecase extends Mock implements SetDcaUsecase {}

void main() {
  test('retry clears the failure and loads the DCA form', () async {
    final startDca = MockStartDcaUsecase();
    final secondLoad = Completer<Result<DcaStartData, DcaFailure>>();
    var calls = 0;
    when(() => startDca.execute()).thenAnswer((_) {
      calls += 1;
      return calls == 1
          ? Future.value(const Err(DcaAccountUnavailableFailure()))
          : secondLoad.future;
    });
    final bloc = DcaBloc(
      startDcaUsecase: startDca,
      setDcaUsecase: MockSetDcaUsecase(),
    );

    final firstFailure = bloc.stream.firstWhere(
      (state) => state is DcaInitialState && state.failure != null,
    );
    bloc.add(const DcaEvent.started());
    await firstFailure;

    final loading = bloc.stream.firstWhere(
      (state) => state is DcaInitialState && state.failure == null,
    );
    bloc.add(const DcaEvent.started());
    await loading;

    final loaded = bloc.stream.firstWhere((state) => state is DcaBuyInputState);
    secondLoad.complete(
      const Ok((
        balances: <UserBalance>[],
        currency: FiatCurrency.cad,
        lightningAddress: null,
      )),
    );
    await loaded;

    verify(() => startDca.execute()).called(2);
    await bloc.close();
  });

  test('two confirmations admit only one DCA creation', () async {
    final start = MockStartDcaUsecase();
    final create = MockSetDcaUsecase();
    const frequency = DcaBuyFrequency.daily;
    const currency = FiatCurrency.cad;
    const network = DcaNetwork.bitcoin;
    final pending = Completer<Result<Dca, DcaFailure>>();
    when(start.execute).thenAnswer(
      (_) async => const Ok((
        balances: <UserBalance>[],
        currency: currency,
        lightningAddress: null,
      )),
    );
    Future<Result<Dca, DcaFailure>> createOrder() => create.execute(
      amount: 10,
      currency: currency,
      frequency: frequency,
      network: network,
    );
    when(createOrder).thenAnswer((_) => pending.future);
    final bloc = DcaBloc(startDcaUsecase: start, setDcaUsecase: create);
    final loaded = bloc.stream.firstWhere((state) => state is DcaBuyInputState);
    bloc.add(const DcaEvent.started());
    await loaded;
    final selecting = bloc.stream.firstWhere(
      (state) => state is DcaWalletSelectionState,
    );
    bloc.add(
      const DcaEvent.buyInputContinuePressed(
        amountInput: '10',
        currency: currency,
        frequency: frequency,
      ),
    );
    await selecting;
    final reviewing = bloc.stream.firstWhere(
      (state) => state is DcaConfirmationState,
    );
    bloc.add(const DcaEvent.walletSelected(network: network));
    await reviewing;
    bloc.add(const DcaEvent.confirmed());
    bloc.add(const DcaEvent.confirmed());
    await Future<void>.delayed(Duration.zero);
    pending.complete(const Err(DcaOrderCreationFailure()));
    await bloc.close();
    verify(createOrder).called(1);
  });
}
