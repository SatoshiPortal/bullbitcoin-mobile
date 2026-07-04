import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'send_cubit_harness.dart';

void main() {
  setUpAll(registerSendCubitHarnessFallbacks);

  SendState lnAddressAmountState(Wallet wallet) => SendState(
    step: SendStep.amount,
    sendType: SendType.lightning,
    paymentRequest: const PaymentRequest.lnAddress(address: 'alice@bullpay.ca'),
    selectedWallet: wallet,
    amount: '1000',
    inputAmountCurrencyCode: 'sats',
    selectedSwapLimits: const SwapLimits(min: 100, max: 1000000),
    selectedSwapFees: const SwapFees(),
  );

  void stubDirectPaySuccess(SendCubitHarness harness) {
    when(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => 'lq1direct');
    when(
      () => harness.prepareLiquidSend.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => harness.calculateLiquidAbsoluteFees.execute(
        pset: any(named: 'pset'),
      ),
    ).thenAnswer((_) async => 1);
  }

  void stubSwapFallback(SendCubitHarness harness, Wallet wallet) {
    when(
      () => harness.createSendSwap.execute(
        walletId: any(named: 'walletId'),
        type: any(named: 'type'),
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
      ),
    ).thenAnswer((_) async => sendCubitLnSendSwap(walletId: wallet.id));
    when(
      () => harness.prepareLiquidSend.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => harness.calculateLiquidAbsoluteFees.execute(
        pset: any(named: 'pset'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => harness.updateSendSwapLockupFees.execute(
        swapId: any(named: 'swapId'),
        lockupFees: any(named: 'lockupFees'),
      ),
    ).thenAnswer((_) async => sendCubitLnSendSwap(walletId: wallet.id));
  }

  test('direct-pay success pays Liquid directly, no swap, annotates', () async {
    final harness = SendCubitHarness();
    final wallet = sendCubitWallet(
      id: 'liquid-wallet',
      label: 'Instant Payments',
      balanceSat: BigInt.from(100000),
    );
    stubDirectPaySuccess(harness);

    final cubit = harness.createCubit();
    addTearDown(cubit.close);
    harness.seed(cubit, lnAddressAmountState(wallet));

    await cubit.onAmountConfirmed();

    verify(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: 'alice@bullpay.ca',
        amountSat: 1000,
        walletId: wallet.id,
      ),
    ).called(1);
    verifyNever(
      () => harness.createSendSwap.execute(
        walletId: any(named: 'walletId'),
        type: any(named: 'type'),
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
      ),
    );
    verify(
      () => harness.prepareLiquidSend.execute(
        walletId: wallet.id,
        address: 'lq1direct',
        networkFee: any(named: 'networkFee'),
        amountSat: 1000,
        drain: false,
      ),
    ).called(1);
    expect(cubit.state.step, SendStep.confirm);
    expect(cubit.state.sendType, SendType.liquid);
    expect(cubit.state.paidViaLiquidDirect, isTrue);
    expect(cubit.state.swapCreationException, isNull);
  });

  test('LiquidDirectPayUnavailable falls back to the swap, no error', () async {
    final harness = SendCubitHarness();
    final wallet = sendCubitWallet(
      id: 'liquid-wallet',
      label: 'Instant Payments',
      balanceSat: BigInt.from(100000),
    );
    when(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
        walletId: any(named: 'walletId'),
      ),
    ).thenThrow(const LiquidDirectPayUnavailable());
    stubSwapFallback(harness, wallet);

    final cubit = harness.createCubit();
    addTearDown(cubit.close);
    harness.seed(cubit, lnAddressAmountState(wallet));

    await cubit.onAmountConfirmed();

    verify(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
        walletId: any(named: 'walletId'),
      ),
    ).called(1);
    verify(
      () => harness.createSendSwap.execute(
        walletId: wallet.id,
        type: SwapType.liquidToLightning,
        lnAddress: 'alice@bullpay.ca',
        amountSat: 1000,
      ),
    ).called(1);
    expect(cubit.state.paidViaLiquidDirect, isFalse);
    expect(cubit.state.swapCreationException, isNull);
  });

  test('BullpayProofError also falls back to the swap', () async {
    final harness = SendCubitHarness();
    final wallet = sendCubitWallet(
      id: 'liquid-wallet',
      label: 'Instant Payments',
      balanceSat: BigInt.from(100000),
    );
    when(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
        walletId: any(named: 'walletId'),
      ),
    ).thenThrow(BullpayProofInvalid(reason: 'asset mismatch'));
    stubSwapFallback(harness, wallet);

    final cubit = harness.createCubit();
    addTearDown(cubit.close);
    harness.seed(cubit, lnAddressAmountState(wallet));

    await cubit.onAmountConfirmed();

    verify(
      () => harness.createSendSwap.execute(
        walletId: wallet.id,
        type: SwapType.liquidToLightning,
        lnAddress: 'alice@bullpay.ca',
        amountSat: 1000,
      ),
    ).called(1);
    expect(cubit.state.paidViaLiquidDirect, isFalse);
  });

  test('a non-Liquid wallet never attempts direct pay', () async {
    final harness = SendCubitHarness();
    final wallet = sendCubitWallet(
      id: 'btc-wallet',
      label: 'Bitcoin',
      network: Network.bitcoinMainnet,
      balanceSat: BigInt.from(100000),
    );
    when(
      () => harness.createSendSwap.execute(
        walletId: any(named: 'walletId'),
        type: any(named: 'type'),
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
      ),
    ).thenAnswer((_) async => sendCubitLnSendSwap(walletId: wallet.id));

    final cubit = harness.createCubit();
    addTearDown(cubit.close);
    harness.seed(cubit, lnAddressAmountState(wallet));

    await cubit.onAmountConfirmed();

    verifyNever(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
        walletId: any(named: 'walletId'),
      ),
    );
    verify(
      () => harness.createSendSwap.execute(
        walletId: wallet.id,
        type: SwapType.bitcoinToLightning,
        lnAddress: 'alice@bullpay.ca',
        amountSat: 1000,
      ),
    ).called(1);
  });

  test('sendMax never attempts direct pay', () async {
    final harness = SendCubitHarness();
    final wallet = sendCubitWallet(
      id: 'liquid-wallet',
      label: 'Instant Payments',
      balanceSat: BigInt.from(100000),
    );
    stubSwapFallback(harness, wallet);

    final cubit = harness.createCubit();
    addTearDown(cubit.close);
    harness.seed(cubit, lnAddressAmountState(wallet).copyWith(sendMax: true));

    await cubit.onAmountConfirmed();

    verifyNever(
      () => harness.tryLiquidDirectPay.execute(
        lnAddress: any(named: 'lnAddress'),
        amountSat: any(named: 'amountSat'),
        walletId: any(named: 'walletId'),
      ),
    );
  });
}
