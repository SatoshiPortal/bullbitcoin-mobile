import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/pay/domain/broadcast_pay_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/sign_pay_payin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPrepareBitcoinSend extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockBroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockBroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockGetWalletUtxos extends Mock implements GetWalletUtxosUsecase {}

/// The shape BDK and LWK actually throw: descriptors, xprvs and addresses.
const _rawReason =
    'BdkError: cannot sign wpkh([aabbccdd]xprv9s21ZrQH143K3/0/*) '
    'to bc1qsecretaddress';

void main() {
  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(const NetworkFee.absolute(200));
    registerFallbackValue(<WalletUtxo>[]);
  });

  group('PreparePayBitcoinPayinUsecase', () {
    late _MockPrepareBitcoinSend prepare;

    setUp(() => prepare = _MockPrepareBitcoinSend());

    void stubThrow(Object error) {
      when(
        () => prepare.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          networkFee: any(named: 'networkFee'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenThrow(error);
    }

    Future<Result<PreparedPayBitcoinPayin, PayFailure>> run() =>
        PreparePayBitcoinPayinUsecase(
          prepareBitcoinSendUsecase: prepare,
        ).execute(
          walletId: 'wallet-1',
          address: 'bc1qpayin',
          networkFee: const NetworkFee.absolute(200),
          amountSat: 100000,
        );

    test('a build failure is sanitized, reason kept for logs only', () async {
      stubThrow(Exception(_rawReason));

      final failure =
          (await run() as Err<PreparedPayBitcoinPayin, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, contains(_rawReason));
    });

    test('short funds is named, exactly as on the Liquid path', () async {
      // PrepareBitcoinSendUsecase rethrows this one so the caller can name it.
      // Folding it into the catch-all told a customer whose balance covers the
      // amount but not the fees to "contact support".
      stubThrow(InsufficientFundsException(_rawReason));

      final failure =
          (await run() as Err<PreparedPayBitcoinPayin, PayFailure>).failure;
      expect(failure, isA<PayInsufficientBalanceFailure>());
      expect(
        (failure as PayInsufficientBalanceFailure).requiredAmountSat,
        100000,
      );
    });

    test('no spendable utxo reads as the same shortfall', () async {
      stubThrow(NoSpendableUtxoException(_rawReason));

      expect(
        (await run() as Err<PreparedPayBitcoinPayin, PayFailure>).failure,
        isA<PayInsufficientBalanceFailure>(),
      );
    });
  });

  group('PreparePayLiquidPayinUsecase', () {
    late _MockLiquidWalletRepository liquidWallet;
    late PreparePayLiquidPayinUsecase usecase;

    setUp(() {
      liquidWallet = _MockLiquidWalletRepository();
      usecase = PreparePayLiquidPayinUsecase(
        liquidWalletRepository: liquidWallet,
      );
    });

    Future<Result<String, PayFailure>> run() => usecase.execute(
      walletId: 'wallet-1',
      address: 'lq1qpayin',
      feeRate: const RelativeFee(25),
      amountSat: 100000,
    );

    void stubThrow(Object error) {
      when(
        () => liquidWallet.buildPset(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          feeRate: any(named: 'feeRate'),
          amountSat: any(named: 'amountSat'),
          drain: any(named: 'drain'),
        ),
      ).thenThrow(error);
    }

    test('short funds becomes an actionable balance failure', () async {
      // These used to reach the catch-all, so the wallet's own words about the
      // shortfall were printed on the payment screen.
      stubThrow(InsufficientFundsException(_rawReason));

      final failure = (await run() as Err<String, PayFailure>).failure;
      expect(failure, isA<PayInsufficientBalanceFailure>());
      expect(
        (failure as PayInsufficientBalanceFailure).requiredAmountSat,
        100000,
      );
      expect(failure.logMessage, _rawReason);
    });

    test('no spendable utxo reads as the same shortfall', () async {
      stubThrow(NoSpendableUtxoException(_rawReason));

      expect(
        (await run() as Err<String, PayFailure>).failure,
        isA<PayInsufficientBalanceFailure>(),
      );
    });

    test('consolidation is sanitized rather than explained raw', () async {
      stubThrow(ConsolidationRequiredException(_rawReason));

      final failure = (await run() as Err<String, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, _rawReason);
    });
  });

  group('SignPayPayinUsecase', () {
    test(
      'a Bitcoin signing failure never carries the descriptor out',
      () async {
        final bitcoinWallet = _MockBitcoinWalletRepository();
        when(
          () => bitcoinWallet.signPsbt(any(), walletId: any(named: 'walletId')),
        ).thenThrow(Exception(_rawReason));

        final result = await SignPayPayinUsecase(
          bitcoinWalletRepository: bitcoinWallet,
          liquidWalletRepository: _MockLiquidWalletRepository(),
        ).bitcoin(psbt: 'psbt', walletId: 'wallet-1');

        final failure =
            (result as Err<({String signedPsbt, int txSize}), PayFailure>)
                .failure;
        expect(failure, isA<PayUnexpectedFailure>());
        expect(failure.logMessage, contains(_rawReason));
      },
    );

    test('a Liquid signing failure is sanitized too', () async {
      final liquidWallet = _MockLiquidWalletRepository();
      when(
        () => liquidWallet.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result = await SignPayPayinUsecase(
        bitcoinWalletRepository: _MockBitcoinWalletRepository(),
        liquidWalletRepository: liquidWallet,
      ).liquid(pset: 'pset', walletId: 'wallet-1');

      expect(
        (result as Err<String, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });
  });

  group('BroadcastPayPayinUsecase', () {
    test('a rejected broadcast is sanitized, not quoted', () async {
      final broadcast = _MockBroadcastBitcoin();
      when(
        () => broadcast.execute(any(), isPsbt: any(named: 'isPsbt')),
      ).thenThrow(Exception(_rawReason));

      final result = await BroadcastPayPayinUsecase(
        broadcastBitcoinTransactionUsecase: broadcast,
        broadcastLiquidTransactionUsecase: _MockBroadcastLiquid(),
      ).bitcoin('rawtx', isPsbt: true);

      final failure = (result as Err<String, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
      expect(failure.logMessage, contains(_rawReason));
    });
  });

  group('LoadPayWalletUtxosUsecase', () {
    test('a utxo read failure is a value, not a throw', () async {
      final utxos = _MockGetWalletUtxos();
      when(
        () => utxos.execute(walletId: any(named: 'walletId')),
      ).thenThrow(Exception(_rawReason));

      final result = await LoadPayWalletUtxosUsecase(
        getWalletUtxosUsecase: utxos,
      ).execute(walletId: 'wallet-1');

      expect(
        (result as Err<List<WalletUtxo>, PayFailure>).failure,
        isA<PayUnexpectedFailure>(),
      );
    });
  });
}
