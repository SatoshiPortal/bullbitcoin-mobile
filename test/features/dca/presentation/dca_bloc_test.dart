import 'package:bull_exchange/testing.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStartDcaUsecase extends Mock implements StartDcaUsecase {}

class MockGetDcaDefaultWalletsUsecase extends Mock
    implements GetDcaDefaultWalletsUsecase {}

class MockSetDcaUsecase extends Mock implements SetDcaUsecase {}

const DcaStartData _startData = (
  balances: <UserBalance>[],
  currency: FiatCurrency.cad,
  lightningAddress: null,
);

const _bitcoinDefault = DefaultWallet(
  walletType: BtcNetwork.bitcoin,
  address: 'tb1qexchangedefault',
);

void main() {
  late MockStartDcaUsecase startDca;
  late MockGetDcaDefaultWalletsUsecase getDefaultWallets;
  late MockSetDcaUsecase setDca;

  setUp(() {
    startDca = MockStartDcaUsecase();
    getDefaultWallets = MockGetDcaDefaultWalletsUsecase();
    setDca = MockSetDcaUsecase();
    when(() => startDca.execute())
        .thenAnswer((_) async => const Ok(_startData));
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(DefaultWallets()));
  });

  DcaBloc build() => DcaBloc(
    startDcaUsecase: startDca,
    getDcaDefaultWalletsUsecase: getDefaultWallets,
    setDcaUsecase: setDca,
  );

  Future<DcaWalletSelectionState> toWalletSelection(DcaBloc bloc) async {
    final loaded = bloc.stream.firstWhere((s) => s is DcaBuyInputState);
    bloc.add(const DcaEvent.started());
    await loaded;
    final selection = bloc.stream.firstWhere(
      (s) => s is DcaWalletSelectionState,
    );
    bloc.add(
      const DcaEvent.buyInputContinuePressed(
        amountInput: '10',
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
      ),
    );
    return (await selection) as DcaWalletSelectionState;
  }

  test('retry clears the failure and loads the DCA form', () async {
    final secondLoad = Completer<Result<DcaStartData, DcaFailure>>();
    var calls = 0;
    when(() => startDca.execute()).thenAnswer((_) {
      calls += 1;
      return calls == 1
          ? Future.value(const Err(DcaAccountUnavailableFailure()))
          : secondLoad.future;
    });
    final bloc = build();

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
    secondLoad.complete(const Ok(_startData));
    await loaded;

    verify(() => startDca.execute()).called(2);
    await bloc.close();
  });

  test('two confirmations admit only one DCA creation', () async {
    final start = MockStartDcaUsecase();
    final create = MockSetDcaUsecase();
    const frequency = DcaBuyFrequency.daily;
    const currency = FiatCurrency.cad;
    const network = BtcNetwork.bitcoin;
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
      address: _bitcoinDefault.address,
    );
    when(createOrder).thenAnswer((_) => pending.future);
    final bloc = DcaBloc(
      startDcaUsecase: start,
      getDcaDefaultWalletsUsecase: getDefaultWallets,
      setDcaUsecase: create,
    );
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
    bloc.add(
      DcaEvent.walletSelected(
        network: network,
        address: _bitcoinDefault.address,
        isDefaultAddress: true,
      ),
    );
    await reviewing;
    bloc.add(const DcaEvent.confirmed());
    bloc.add(const DcaEvent.confirmed());
    await Future<void>.delayed(Duration.zero);
    pending.complete(const Err(DcaOrderCreationFailure()));
    await bloc.close();
    verify(createOrder).called(1);
  test('the form carries the exchange default wallets', () async {
    when(() => getDefaultWallets.execute()).thenAnswer(
      (_) async => const Ok(DefaultWallets(bitcoin: _bitcoinDefault)),
    );
    final bloc = build();

    final selection = await toWalletSelection(bloc);

    expect(selection.defaultWallets.bitcoin, _bitcoinDefault);
    await bloc.close();
  });

  test('a failed default wallets read stops at the retryable failure, not at '
      'a form without destinations', () async {
    when(() => getDefaultWallets.execute())
        .thenAnswer((_) async => const Err(DcaAccountUnavailableFailure()));
    final bloc = build();

    final failed = bloc.stream.firstWhere(
      (s) => s is DcaInitialState && s.failure != null,
    );
    bloc.add(const DcaEvent.started());
    final state = await failed as DcaInitialState;

    expect(state.failure, isA<DcaAccountUnavailableFailure>());
    await bloc.close();
  });

  test('confirming sends the address chosen at wallet selection', () async {
    when(() => getDefaultWallets.execute()).thenAnswer(
      (_) async => const Ok(DefaultWallets(bitcoin: _bitcoinDefault)),
    );
    when(
      () => setDca.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.bitcoin,
        address: _bitcoinDefault.address,
      ),
    ).thenAnswer(
      (_) async => Ok(
        Dca(
          amount: 10,
          currency: FiatCurrency.cad,
          frequency: DcaBuyFrequency.daily,
          network: BtcNetwork.bitcoin,
          address: _bitcoinDefault.address,
          nextPurchaseDate: DateTime(2026),
        ),
      ),
    );
    final bloc = build();
    await toWalletSelection(bloc);

    final confirmation = bloc.stream.firstWhere(
      (s) => s is DcaConfirmationState,
    );
    bloc.add(
      DcaEvent.walletSelected(
        network: BtcNetwork.bitcoin,
        address: _bitcoinDefault.address,
        isDefaultAddress: true,
      ),
    );
    final confirming = (await confirmation) as DcaConfirmationState;
    expect(confirming.address, _bitcoinDefault.address);
    expect(confirming.isDefaultAddress, isTrue);

    final success = bloc.stream.firstWhere((s) => s is DcaSuccessState);
    bloc.add(const DcaEvent.confirmed());
    await success;

    verify(
      () => setDca.execute(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.daily,
        network: BtcNetwork.bitcoin,
        address: _bitcoinDefault.address,
      ),
    ).called(1);
    await bloc.close();
  });

  test('coming back from the default wallets editor re-reads the default '
      'wallets on the wallet-selection step', () async {
    var reads = 0;
    when(() => getDefaultWallets.execute()).thenAnswer((_) async {
      reads += 1;
      return reads == 1
          ? const Ok(DefaultWallets())
          : const Ok(DefaultWallets(bitcoin: _bitcoinDefault));
    });
    final bloc = build();
    final selection = await toWalletSelection(bloc);
    expect(selection.defaultWallets.bitcoin, isNull);

    final refreshed = bloc.stream.firstWhere(
      (s) => s is DcaWalletSelectionState && s.defaultWallets.bitcoin != null,
    );
    bloc.add(const DcaEvent.defaultWalletsRefreshRequested());
    final state = (await refreshed) as DcaWalletSelectionState;

    expect(state.defaultWallets.bitcoin, _bitcoinDefault);
    expect(state.amount, 10);
    await bloc.close();
  });
}
