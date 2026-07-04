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
        feeRate: any(named: 'feeRate'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () =>
          harness.calculateLiquidAbsoluteFees.execute(pset: any(named: 'pset')),
    ).thenAnswer((_) async => 1);
    when(
      () => harness.calculateLiquidPsetSize.execute(pset: any(named: 'pset')),
    ).thenAnswer((_) async => 1000);
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
        feeRate: any(named: 'feeRate'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () =>
          harness.calculateLiquidAbsoluteFees.execute(pset: any(named: 'pset')),
    ).thenAnswer((_) async => 1);
    when(
      () => harness.calculateLiquidPsetSize.execute(pset: any(named: 'pset')),
    ).thenAnswer((_) async => 1000);
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
    // Twice: a placeholder pset for absolute→relative fee-rate resolution
    // (_resolveLiquidFeeRate), then the real build — both against lq1direct.
    verify(
      () => harness.prepareLiquidSend.execute(
        walletId: wallet.id,
        address: 'lq1direct',
        feeRate: any(named: 'feeRate'),
        amountSat: 1000,
        drain: false,
      ),
    ).called(2);
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

  test(
    'a stale swap fallback does not hijack a later direct-pay rail',
    () async {
      // Regression for the MEDIUM stale-swap coupling: direct-pay fails once (a
      // swap fallback is created and left in state), the user goes back, then a
      // retry succeeds. createTransaction() prioritizes a non-null swap
      // address+amount over the paymentRequest, so without clearing the stale
      // swap the direct rail would silently build against the swap address.
      final harness = SendCubitHarness();
      final wallet = sendCubitWallet(
        id: 'liquid-wallet',
        label: 'Instant Payments',
        balanceSat: BigInt.from(100000),
      );
      var attempt = 0;
      when(
        () => harness.tryLiquidDirectPay.execute(
          lnAddress: any(named: 'lnAddress'),
          amountSat: any(named: 'amountSat'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async {
        attempt++;
        if (attempt == 1) throw const LiquidDirectPayUnavailable();
        return 'lq1direct';
      });
      stubSwapFallback(harness, wallet); // swap paymentAddress == 'lq1swap'

      final cubit = harness.createCubit();
      addTearDown(cubit.close);
      harness.seed(cubit, lnAddressAmountState(wallet));

      // 1) First confirm: direct-pay fails -> Lightning swap fallback created.
      await cubit.onAmountConfirmed();
      expect(
        cubit.state.lightningSwap,
        isNotNull,
        reason: 'precondition: swap fallback must be set',
      );
      expect(cubit.state.step, SendStep.confirm);

      // 2) User taps back (confirm -> amount); this does NOT clear the swap.
      cubit.backClicked();
      expect(cubit.state.lightningSwap, isNotNull);

      // From here we only care about the tx-build calls.
      clearInteractions(harness.prepareLiquidSend);

      // 3) Re-confirm: direct-pay now succeeds and must commit the DIRECT rail.
      await cubit.onAmountConfirmed();

      expect(cubit.state.paidViaLiquidDirect, isTrue);
      expect(cubit.state.lightningSwap, isNull);
      expect(cubit.state.chainSwap, isNull);
      // The tx is built against the direct address/amount, never the stale
      // swap. Twice: placeholder pset for fee-rate resolution + the real build.
      verify(
        () => harness.prepareLiquidSend.execute(
          walletId: wallet.id,
          address: 'lq1direct',
          feeRate: any(named: 'feeRate'),
          amountSat: 1000,
          drain: false,
        ),
      ).called(2);
      verifyNever(
        () => harness.prepareLiquidSend.execute(
          walletId: any(named: 'walletId'),
          address: 'lq1swap',
          feeRate: any(named: 'feeRate'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
        ),
      );
    },
  );

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
