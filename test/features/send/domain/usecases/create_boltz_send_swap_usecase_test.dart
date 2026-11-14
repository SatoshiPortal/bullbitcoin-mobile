import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/boltz_swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_boltz_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_send_swap_route_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:swaps/swaps.dart' as boltz;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateLightningSendSwapUsecase extends Mock
    implements boltz.CreateLightningSendSwapUsecase {}

class _MockSwapFacade extends Mock implements SwapFacade {}

class _MockLnSendSwap extends Mock implements boltz.LnSendSwap {}

Wallet _liquidWallet() => Wallet(
  origin: 'w-liquid',
  network: Network.liquidMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(100000),
);

const _invoice =
    PaymentRequest.bolt11(
          invoice: 'lnbc1-invoice',
          amountSat: 50000,
          paymentHash: 'hash',
          expiresAt: 0,
          isTestnet: false,
        )
        as Bolt11PaymentRequest;

void main() {
  test('creates the swap from the wallet chain and invoice amount', () async {
    final create = _MockCreateLightningSendSwapUsecase();
    final swap = _MockLnSendSwap();
    when(
      () => create.execute(
        walletId: 'w-liquid',
        invoice: 'lnbc1-invoice',
        invoiceAmountSat: 50000,
        fromLiquid: true,
      ),
    ).thenAnswer((_) async => Ok(swap));

    final result = await CreateBoltzSendSwapUsecase(
      create,
    ).execute(wallet: _liquidWallet(), invoice: _invoice);

    expect((result as Ok).value, same(swap));
  });

  test('reads the swap route from the swap feature', () async {
    final facade = _MockSwapFacade();
    when(
      () => facade.getRoute(),
    ).thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);

    expect(
      await GetSendSwapRouteUsecase(facade).execute(),
      SwapRoute.boltzWithExchangeFallback,
    );
  });

  group('Boltz failures shown on send', () {
    const limits = boltz.SwapsAmountOutOfLimitsFailure(
      minSat: 1000,
      maxSat: 2000000,
    );

    test('below the minimum reports the minimum', () {
      final failure =
          limits.toSendFailure(amountSat: 500) as SendAmountOutOfBoundsFailure;
      expect(failure.minimumSat, BigInt.from(1000));
      expect(failure.maximumSat, isNull);
    });

    test('above the maximum reports the maximum', () {
      final failure =
          limits.toSendFailure(amountSat: 3000000)
              as SendAmountOutOfBoundsFailure;
      expect(failure.minimumSat, isNull);
      expect(failure.maximumSat, BigInt.from(2000000));
    });

    test('an unavailable or refusing Boltz is a swap creation failure', () {
      expect(
        const boltz.SwapsBoltzUnavailableFailure().toSendFailure(amountSat: 1),
        isA<SendSwapCreationFailure>(),
      );
      expect(
        const boltz.SwapsBoltzRejectedFailure().toSendFailure(amountSat: 1),
        isA<SendSwapCreationFailure>(),
      );
    });
  });
}
