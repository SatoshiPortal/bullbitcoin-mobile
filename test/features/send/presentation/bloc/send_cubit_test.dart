import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_send_swap_lockup_fees_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/verify_chain_swap_amount_send_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_liquid_tx_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLabelsFacade extends Mock implements LabelsFacade {}

class MockSelectBestWalletUsecase extends Mock
    implements SelectBestWalletUsecase {}

class MockDetectBitcoinStringUsecase extends Mock
    implements DetectBitcoinStringUsecase {}

class MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class MockGetNetworkFeesUsecase extends Mock implements GetNetworkFeesUsecase {}

class MockGetWalletUtxosUsecase extends Mock implements GetWalletUtxosUsecase {}

class MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class MockSendWithPayjoinUsecase extends Mock
    implements SendWithPayjoinUsecase {}

class MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class MockCreateSendSwapUsecase extends Mock implements CreateSendSwapUsecase {}

class MockUpdatePaidSendSwapUsecase extends Mock
    implements UpdatePaidSendSwapUsecase {}

class MockGetSwapLimitsUsecase extends Mock implements GetSwapLimitsUsecase {}

class MockWatchSwapUsecase extends Mock implements WatchSwapUsecase {}

class MockWatchFinishedWalletSyncsUsecase extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class MockDecodeInvoiceUsecase extends Mock implements DecodeInvoiceUsecase {}

class MockSignBitcoinTxUsecase extends Mock implements SignBitcoinTxUsecase {}

class MockSignLiquidTxUsecase extends Mock implements SignLiquidTxUsecase {}

class MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class MockCreateChainSwapToExternalUsecase extends Mock
    implements CreateChainSwapToExternalUsecase {}

class MockWatchWalletTransactionByTxIdUsecase extends Mock
    implements WatchWalletTransactionByTxIdUsecase {}

class MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class MockUpdateSendSwapLockupFeesUsecase extends Mock
    implements UpdateSendSwapLockupFeesUsecase {}

class MockVerifyChainSwapAmountSendUsecase extends Mock
    implements VerifyChainSwapAmountSendUsecase {}

void main() {
  SendCubit buildCubit({
    MockDetectBitcoinStringUsecase? detectBitcoinStringUsecase,
  }) {
    return SendCubit(
      labelsFacade: MockLabelsFacade(),
      bestWalletUsecase: MockSelectBestWalletUsecase(),
      detectBitcoinStringUsecase:
          detectBitcoinStringUsecase ?? MockDetectBitcoinStringUsecase(),
      getSettingsUsecase: MockGetSettingsUsecase(),
      convertSatsToCurrencyAmountUsecase:
          MockConvertSatsToCurrencyAmountUsecase(),
      getNetworkFeesUsecase: MockGetNetworkFeesUsecase(),
      getWalletUtxosUsecase: MockGetWalletUtxosUsecase(),
      getAvailableCurrenciesUsecase: MockGetAvailableCurrenciesUsecase(),
      prepareBitcoinSendUsecase: MockPrepareBitcoinSendUsecase(),
      prepareLiquidSendUsecase: MockPrepareLiquidSendUsecase(),
      sendWithPayjoinUsecase: MockSendWithPayjoinUsecase(),
      getWalletsUsecase: MockGetWalletsUsecase(),
      getWalletUsecase: MockGetWalletUsecase(),
      createSendSwapUsecase: MockCreateSendSwapUsecase(),
      updatePaidSendSwapUsecase: MockUpdatePaidSendSwapUsecase(),
      getSwapLimitsUsecase: MockGetSwapLimitsUsecase(),
      watchSwapUsecase: MockWatchSwapUsecase(),
      watchFinishedWalletSyncsUsecase: MockWatchFinishedWalletSyncsUsecase(),
      decodeInvoiceUsecase: MockDecodeInvoiceUsecase(),
      signBitcoinTxUsecase: MockSignBitcoinTxUsecase(),
      signLiquidTxUsecase: MockSignLiquidTxUsecase(),
      broadcastBitcoinTxUsecase: MockBroadcastBitcoinTransactionUsecase(),
      broadcastLiquidTxUsecase: MockBroadcastLiquidTransactionUsecase(),
      calculateLiquidAbsoluteFeesUsecase:
          MockCalculateLiquidAbsoluteFeesUsecase(),
      createChainSwapToExternalUsecase: MockCreateChainSwapToExternalUsecase(),
      watchWalletTransactionByTxIdUsecase:
          MockWatchWalletTransactionByTxIdUsecase(),
      calculateBitcoinAbsoluteFeesUsecase:
          MockCalculateBitcoinAbsoluteFeesUsecase(),
      updateSendSwapLockupFeesUsecase: MockUpdateSendSwapLockupFeesUsecase(),
      verifyChainSwapAmountSendUsecase: MockVerifyChainSwapAmountSendUsecase(),
    );
  }

  group('onChangedText', () {
    test('stores sanitized input without parsing it', () {
      final detectBitcoinStringUsecase = MockDetectBitcoinStringUsecase();
      final cubit = buildCubit(
        detectBitcoinStringUsecase: detectBitcoinStringUsecase,
      );
      addTearDown(cubit.close);

      cubit.onChangedText('  "user@example.com"  ');

      expect(cubit.state.copiedRawPaymentRequest, 'user@example.com');
      expect(cubit.state.paymentRequest, isNull);
      expect(cubit.state.invalidBitcoinStringException, isNull);
      verifyNever(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      );
    });
  });

  group('continueOnAddressConfirmed', () {
    test(
      'parses current input and emits invalid state only when submit fails',
      () async {
        final detectBitcoinStringUsecase = MockDetectBitcoinStringUsecase();
        final cubit = buildCubit(
          detectBitcoinStringUsecase: detectBitcoinStringUsecase,
        );
        addTearDown(cubit.close);

        when(
          () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
        ).thenThrow(Exception('invalid'));

        cubit.onChangedText('invalid-address');
        await cubit.continueOnAddressConfirmed();

        verify(
          () => detectBitcoinStringUsecase.execute(data: 'invalid-address'),
        ).called(1);
        expect(cubit.state.loadingBestWallet, isFalse);
        expect(cubit.state.paymentRequest, isNull);
        expect(cubit.state.invalidBitcoinStringException, isNotNull);
      },
    );

    test('uses cached scanned request without reparsing it', () async {
      final detectBitcoinStringUsecase = MockDetectBitcoinStringUsecase();
      final cubit = buildCubit(
        detectBitcoinStringUsecase: detectBitcoinStringUsecase,
      );
      addTearDown(cubit.close);

      await cubit.onScannedPaymentRequest(
        '  user@example.com  ',
        const PaymentRequest.lnAddress(address: 'user@example.com'),
      );

      expect(cubit.state.copiedRawPaymentRequest, 'user@example.com');
      expect(cubit.state.paymentRequest, isA<LnAddressPaymentRequest>());
      verifyNever(
        () => detectBitcoinStringUsecase.execute(data: any(named: 'data')),
      );
    });
  });
}
