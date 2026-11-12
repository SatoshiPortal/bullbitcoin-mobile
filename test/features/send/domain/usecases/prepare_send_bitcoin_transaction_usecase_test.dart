import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_send_bitcoin_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../../coins/wallet_utxo_fixture.dart';

class _MockPrepare extends Mock implements PrepareBitcoinSendUsecase {}

void main() {
  const fee = NetworkFee.absolute(200);
  final cases = <(String, WalletFailure, bool, bool, Matcher)>[
    (
      'unavailable selection',
      const WalletSelectedInputsUnavailableFailure(),
      true,
      false,
      isA<SendSelectedCoinsUnavailableFailure>(),
    ),
    (
      'automatic shortfall',
      const WalletInsufficientFundsFailure(),
      false,
      false,
      isA<SendInsufficientFundsForFeesFailure>(),
    ),
    (
      'selected shortfall',
      const WalletInsufficientFundsFailure(),
      true,
      false,
      isA<SendSelectedCoinsInsufficientFailure>(),
    ),
    (
      'frozen shortfall',
      const WalletInsufficientFundsFailure(),
      false,
      true,
      isA<SendInsufficientBalanceFailure>(),
    ),
    (
      'empty wallet',
      const WalletNoSpendableInputsFailure(),
      false,
      false,
      isA<SendInsufficientBalanceFailure>(),
    ),
    (
      'spent selection',
      const WalletNoSpendableInputsFailure(),
      true,
      false,
      isA<SendSelectedCoinsUnavailableFailure>(),
    ),
    (
      'construction failure',
      const WalletTransactionBuildFailure(),
      false,
      false,
      isA<SendTransactionBuildFailure>(),
    ),
  ];

  for (final (name, failure, selected, frozen, expected) in cases) {
    test('maps $name to its actionable Send failure', () async {
      final prepare = _MockPrepare();
      final inputs = [if (selected) walletUtxoFixture()];
      when(
        () => prepare.execute(
          walletId: 'wallet-1',
          address: 'recipient',
          networkFee: fee,
          amountSat: 10000,
          selectedInputs: inputs,
        ),
      ).thenAnswer((_) async => Err(failure));

      final result = await PrepareSendBitcoinTransactionUsecase(prepare)
          .execute(
            walletId: 'wallet-1',
            address: 'recipient',
            networkFee: fee,
            amountSat: 10000,
            selectedInputs: inputs,
            hasFrozenInputs: frozen,
          );

      expect(
        result,
        isA<Err<PreparedBitcoinSend, SendFailure>>().having(
          (error) => error.failure,
          'failure',
          expected,
        ),
      );
    });
  }

  test('preserves the prepared transaction on success', () async {
    final prepare = _MockPrepare();
    const transaction = (unsignedPsbt: 'psbt', txSize: 110, isToSelf: false);
    when(
      () => prepare.execute(
        walletId: 'wallet-1',
        address: 'recipient',
        networkFee: fee,
        amountSat: 10000,
      ),
    ).thenAnswer((_) async => const Ok(transaction));

    final result = await PrepareSendBitcoinTransactionUsecase(prepare).execute(
      walletId: 'wallet-1',
      address: 'recipient',
      networkFee: fee,
      amountSat: 10000,
    );

    expect(
      result,
      isA<Ok<PreparedBitcoinSend, SendFailure>>().having(
        (success) => success.value,
        'transaction',
        transaction,
      ),
    );
  });
}
