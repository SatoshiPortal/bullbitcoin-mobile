import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network, Ok, Err;
import 'package:swaps/order_swaps.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:secrets/testing.dart' show walletRegistrationForTesting;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/get_send_cross_chain_quote_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderSwaps extends Mock implements OrderSwaps {}

void main() {
  late _MockOrderSwaps swapFacade;
  late GetSendCrossChainQuoteUsecase usecase;

  setUp(() {
    swapFacade = _MockOrderSwaps();
    usecase = GetSendCrossChainQuoteUsecase(swapFacade);
  });

  for (final network in const <Network>[
    BitcoinNetwork.regtest,
    LiquidNetwork.regtest,
  ]) {
    test('$network refuses before requesting a remote quote', () async {
      final result = await usecase.execute(
        wallet: _wallet(network),
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
      );
      expect(
        result,
        isA<Err>().having(
          (result) => result.failure,
          'failure',
          isA<SendSwapRouteUnavailableFailure>(),
        ),
      );
      verifyZeroInteractions(swapFacade);
    });
  }

  for (final isTestnet in [false, true]) {
    final environment = isTestnet
        ? OrderSwapEnvironment.testnet
        : OrderSwapEnvironment.mainnet;
    final network = isTestnet ? LiquidNetwork.testnet : LiquidNetwork.mainnet;
    test('$environment quotes Liquid to Bitcoin as exact output', () async {
      when(
        () => swapFacade.getQuote(
          environment: environment,
          amountSat: BigInt.from(100000),
          isInAmountFixed: false,
          inNetwork: OrderSwapNetwork.liquid,
          outNetwork: OrderSwapNetwork.bitcoin,
        ),
      ).thenAnswer((_) async => Ok(_quote()));

      final result = await usecase.execute(
        wallet: _wallet(network),
        amountSat: BigInt.from(100000),
        isInAmountFixed: false,
      );

      expect(result, isA<Ok<OrderSwapQuote, SendFailure>>());
    });
  }

  test('quotes Bitcoin to Liquid as exact output', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(100000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.liquid,
      ),
    ).thenAnswer(
      (_) async => Ok(
        _quote(
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.liquid,
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(BitcoinNetwork.testnet),
      amountSat: BigInt.from(100000),
      isInAmountFixed: false,
    );

    expect(result, isA<Ok<OrderSwapQuote, SendFailure>>());
  });
}

SendSource _wallet(Network network) => SendSource(
  walletRegistrationForTesting(
    id: 'wallet-1',
    network: network,
    signer: WalletSigner.local,
  ),
  BigInt.from(200000),
  null,
);

OrderSwapQuote _quote({
  OrderSwapNetwork inNetwork = OrderSwapNetwork.liquid,
  OrderSwapNetwork outNetwork = OrderSwapNetwork.bitcoin,
}) => OrderSwapQuote(
  inAmountSat: BigInt.from(101000),
  outAmountSat: BigInt.from(100000),
  inNetwork: inNetwork,
  outNetwork: outNetwork,
  inCurrency: inNetwork == OrderSwapNetwork.liquid ? 'LBTC' : 'BTC',
  outCurrency: outNetwork == OrderSwapNetwork.liquid ? 'LBTC' : 'BTC',
  feeBasisPoints: 100,
  warnings: const [],
);
