import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

import 'public_bitcoin_fixture.dart';

void main() {
  test('equal preset rates reuse one exact prepared PSBT', () async {
    final spend = _PresetSpend();
    final result = await spend.previewBitcoinFeePresets(
      walletId: 'wallet',
      recipients: [
        BitcoinTransactionRecipient.remainder(address: 'destination'),
      ],
      presets: const FeeOptions(
        fastest: RelativeFee(500),
        economic: RelativeFee(500),
        slow: RelativeFee(250),
        minRelay: RelativeFee(25),
      ),
      replaceByFee: true,
      selectedInputs: {},
    );
    final slots = result.fold(
      (value) => value,
      (failure) => throw StateError('Unexpected result: $failure'),
    );
    expect(spend.rates, [const RelativeFee(500), const RelativeFee(250)]);
    final fastest = slots[FeeSelection.fastest]?.prepared;
    expect(fastest, isNotNull);
    expect(slots[FeeSelection.economic]?.prepared, same(fastest));
    expect(slots, contains(FeeSelection.slow));
    expect(slots[FeeSelection.slow], isNull);
  });

  test(
    'prepared amounts and partially accepted txids are defensive copies',
    () {
      final amounts = [Sats.fromInt(400)];
      final prepared = SpendFixtures.preparedBitcoin(
        unsignedPsbt: 'test value',
        fee: Sats.fromInt(17),
        recipientAmountsSat: amounts,
      );
      amounts.clear();
      expect(prepared.recipientAmountsSat, [Sats.fromInt(400)]);
      expect(
        () => prepared.recipientAmountsSat.clear(),
        throwsUnsupportedError,
      );

      final accepted = ['first'];
      final failure = SpendConsolidationInterruptedFailure(
        accepted,
        const SpendBroadcastOutcomeUnknownFailure(),
      );
      accepted.add('not accepted');
      expect(failure.acceptedTxids, ['first']);
      expect(() => failure.acceptedTxids.clear(), throwsUnsupportedError);
      expect(failure.cause, isA<SpendBroadcastOutcomeUnknownFailure>());
    },
  );

  test('a valid PSBT describing different outputs is rejected', () {
    final different = publicBitcoinPsbt.replaceFirst('AaCGAQ', 'AaGGAQ');
    expect(
      SpendFixtures.verifyBitcoin(
        unsignedPsbt: publicBitcoinPsbt,
        signedTransaction: different,
        isPsbt: true,
      ),
      isA<Err<void, SpendFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<SpendSignedTransactionMismatchFailure>(),
      ),
    );
  });
}

final class _PresetSpend extends FakeSpend {
  final rates = <NetworkFee>[];

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    rates.add(networkFee);
    return networkFee == const RelativeFee(250)
        ? const Err(SpendInsufficientFundsFailure())
        : Ok(
            SpendFixtures.preparedBitcoin(
              unsignedPsbt: 'fixture',
              fee: Sats.fromInt(10),
            ),
          );
  }
}
