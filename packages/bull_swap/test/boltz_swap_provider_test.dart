import 'package:bull_swap/bull_swap.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _FakeEngine implements BoltzEnginePort {
  String? lastClaimed;

  @override
  Future<Result<CreatedSwap, SwapFailure>> createChainSwap({
    required SwapNetwork fromNetwork,
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required String payoutAddress,
    required String refundAddress,
    String? sourceWalletId,
    String? destinationWalletId,
    required SwapEnvironment environment,
  }) async => Ok(
    CreatedSwap(
      providerId: 'boltz-default',
      swapId: 'boltz-1',
      environment: environment,
      inNetwork: fromNetwork,
      outNetwork: toNetwork,
      payinAmountSat: amountSat,
      payoutAmountSat: amountSat,
      payinAddress: 'bc1qboltz',
    ),
  );

  @override
  Future<Result<String, SwapFailure>> claim(
    String swapId, {
    required SwapEnvironment environment,
  }) async {
    lastClaimed = swapId;
    return Ok('claim-tx');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  const config = SwapProviderConfig(
    id: 'boltz-default',
    kind: SwapProviderKind.boltz,
    name: 'Boltz',
    baseUrl: 'api.boltz.exchange',
    isBuiltIn: true,
  );

  test('delegates createChainSwap to the engine', () async {
    final provider = BoltzSwapProvider(_FakeEngine(), config: config);

    final result = await provider.createChainSwap(
      fromNetwork: SwapNetwork.bitcoin,
      toNetwork: SwapNetwork.liquid,
      amountSat: BigInt.from(50000),
      isInAmountFixed: true,
      payoutAddress: 'lq1payout',
      refundAddress: 'bc1refund',
      environment: SwapEnvironment.mainnet,
    );

    expect((result as Ok).value.swapId, 'boltz-1');
  });

  test('is claim/refund capable and delegates claim', () async {
    final engine = _FakeEngine();
    final provider = BoltzSwapProvider(engine, config: config);

    expect(provider, isA<ClaimRefundCapable>());
    final result = await (provider as ClaimRefundCapable).claim(
      'boltz-1',
      environment: SwapEnvironment.mainnet,
    );

    expect((result as Ok).value, 'claim-tx');
    expect(engine.lastClaimed, 'boltz-1');
  });
}
