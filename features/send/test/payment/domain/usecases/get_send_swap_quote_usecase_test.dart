import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network, Ok, Err;
import 'package:swaps/order_swaps.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:secrets/testing.dart' show walletRegistrationForTesting;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/usecases/get_send_swap_quote_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderSwaps extends Mock implements OrderSwaps {}

void main() {
  late _MockOrderSwaps swapFacade;
  late GetSendSwapQuoteUsecase usecase;

  setUp(() {
    swapFacade = _MockOrderSwaps();
    usecase = GetSendSwapQuoteUsecase(swapFacade);
  });

  for (final network in const <Network>[
    BitcoinNetwork.regtest,
    LiquidNetwork.regtest,
  ]) {
    test('$network refuses before requesting a remote quote', () async {
      final result = await usecase.execute(
        wallet: _wallet(network),
        amountSat: BigInt.from(1000),
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
    final network = isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    test(
      '$environment requests only the selected wallet route in output-fixed mode',
      () async {
        when(
          () => swapFacade.getQuote(
            environment: environment,
            amountSat: BigInt.from(1000),
            isInAmountFixed: false,
            inNetwork: OrderSwapNetwork.bitcoin,
            outNetwork: OrderSwapNetwork.lightning,
          ),
        ).thenAnswer(
          (_) async => Ok(
            OrderSwapQuote(
              inAmountSat: BigInt.from(1010),
              outAmountSat: BigInt.from(1000),
              inNetwork: OrderSwapNetwork.bitcoin,
              outNetwork: OrderSwapNetwork.lightning,
              inCurrency: 'BTC',
              outCurrency: 'BTCLN',
              feeBasisPoints: 100,
              warnings: const [],
            ),
          ),
        );

        final result = await usecase.execute(
          wallet: _wallet(network),
          amountSat: BigInt.from(1000),
        );

        expect(result, isA<Ok<OrderSwapQuote, SendFailure>>());
        verify(
          () => swapFacade.getQuote(
            environment: environment,
            amountSat: BigInt.from(1000),
            isInAmountFixed: false,
            inNetwork: OrderSwapNetwork.bitcoin,
            outNetwork: OrderSwapNetwork.lightning,
          ),
        ).called(1);
      },
    );
  }

  test('preserves an API minimum in the Send failure family', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.testnet,
        amountSat: BigInt.from(100),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
      ),
    ).thenAnswer(
      (_) async => Err(
        SwapAmountOutOfBoundsFailure(
          limitAmountSat: BigInt.from(500),
          isMinimum: true,
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(LiquidNetwork.testnet),
      amountSat: BigInt.from(100),
    );

    final failure = (result as Err<OrderSwapQuote, SendFailure>).failure;
    expect(failure, isA<SendAmountOutOfBoundsFailure>());
    expect(
      (failure as SendAmountOutOfBoundsFailure).minimumSat,
      BigInt.from(500),
    );
  });

  test('requests a mainnet quote for a mainnet wallet', () async {
    when(
      () => swapFacade.getQuote(
        environment: OrderSwapEnvironment.mainnet,
        amountSat: BigInt.from(1000),
        isInAmountFixed: false,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
      ),
    ).thenAnswer(
      (_) async => Ok(
        OrderSwapQuote(
          inAmountSat: BigInt.from(1010),
          outAmountSat: BigInt.from(1000),
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.lightning,
          inCurrency: 'BTC',
          outCurrency: 'BTCLN',
          feeBasisPoints: 100,
          warnings: const [],
        ),
      ),
    );

    final result = await usecase.execute(
      wallet: _wallet(BitcoinNetwork.mainnet),
      amountSat: BigInt.from(1000),
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
  BigInt.from(100000),
  null,
);
