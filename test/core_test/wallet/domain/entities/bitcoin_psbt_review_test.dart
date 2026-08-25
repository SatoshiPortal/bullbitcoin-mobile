import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizes recipient and wallet-owned outputs', () {
    final review = BitcoinPsbtReview(
      transactionId: 'txid',
      inputs: [_input()],
      outputs: [
        _output(index: 0, amountSat: 8000),
        _output(index: 1, amountSat: 1000, isWalletOwned: true),
      ],
      feeSat: BigInt.from(1000),
      estimatedTransactionVsize: 100,
      lockTime: 0,
      version: 2,
    );

    expect(review.recipients, hasLength(1));
    expect(review.walletOwnedOutputs, hasLength(1));
    expect(review.recipientAmountSat, BigInt.from(8000));
    expect(review.estimatedFeeRateSatPerVbyte, 10);
    expect(review.outpoints, {'00:0'});
  });

  test('rejects an empty transaction', () {
    expect(
      () => BitcoinPsbtReview(
        transactionId: 'txid',
        inputs: const [],
        outputs: [_output(index: 0, amountSat: 1)],
        feeSat: BigInt.zero,
        estimatedTransactionVsize: 100,
        lockTime: 0,
        version: 2,
      ),
      throwsArgumentError,
    );
  });

  test('reports only descriptor keys signed on every input of a keychain', () {
    final review = BitcoinPsbtReview(
      transactionId: 'txid',
      inputs: [
        _input(signedDescriptorKeyIds: const {'key-a', 'key-b'}),
        _input(outpoint: '11:1', signedDescriptorKeyIds: const {'key-a'}),
      ],
      outputs: [_output(index: 0, amountSat: 9000)],
      feeSat: BigInt.from(1000),
      estimatedTransactionVsize: 100,
      lockTime: 0,
      version: 2,
    );

    expect(review.signedDescriptorKeyIdsByKeychain, {
      BitcoinPolicyKeychain.external: {'key-a'},
    });
    expect(review.signedDescriptorKeyIdsByOutpoint, {
      '00:0': {'key-a', 'key-b'},
      '11:1': {'key-a'},
    });
  });

  test('detects an unsatisfied absolute transaction locktime', () {
    final review = _review(lockTime: 101);
    final maturity = _maturity(confirmations: 20, tipHeight: 100);

    expect(review.hasTimingConstraint, isTrue);
    expect(review.timingIsSatisfied(maturity), isFalse);
    expect(
      review.blockingTimingActivation(maturity),
      isA<BitcoinPolicyActivation>()
          .having(
            (activation) => activation.type,
            'type',
            BitcoinPolicyActivationType.absoluteBlock,
          )
          .having((activation) => activation.value, 'height', 101),
    );
    expect(
      review.timingIsSatisfied(_maturity(confirmations: 20, tipHeight: 101)),
      isTrue,
    );
  });

  test('checks relative transaction locktime against each input', () {
    final review = _review(sequence: 10);

    expect(review.hasTimingConstraint, isTrue);
    expect(
      review.timingIsSatisfied(_maturity(confirmations: 9, tipHeight: 100)),
      isFalse,
    );
    expect(
      review.blockingTimingActivation(
        _maturity(confirmations: 9, tipHeight: 100),
      ),
      isA<BitcoinPolicyActivation>()
          .having(
            (activation) => activation.type,
            'type',
            BitcoinPolicyActivationType.relativeBlocks,
          )
          .having((activation) => activation.value, 'remaining blocks', 1),
    );
    expect(
      review.timingIsSatisfied(_maturity(confirmations: 10, tipHeight: 100)),
      isTrue,
    );
  });

  test('ignores transaction timelock fields that are not active', () {
    expect(
      _review(lockTime: 101, sequence: 0xffffffff).hasTimingConstraint,
      isFalse,
    );
    expect(_review(sequence: 0x8000000a).hasTimingConstraint, isFalse);
    expect(_review(sequence: 10, version: 1).hasTimingConstraint, isFalse);
  });

  test('checks time-based transaction conditions against median time', () {
    final absolute = _review(lockTime: 600000000);
    expect(
      absolute.timingIsSatisfied(
        _maturity(confirmations: 20, tipHeight: 100, medianTimePast: 600000000),
      ),
      isFalse,
    );
    expect(
      absolute.timingIsSatisfied(
        _maturity(confirmations: 20, tipHeight: 100, medianTimePast: 600000001),
      ),
      isTrue,
    );

    final relative = _review(sequence: (1 << 22) | 2);
    expect(
      relative.timingIsSatisfied(
        _maturity(
          confirmations: 20,
          tipHeight: 100,
          medianTimePast: 600001023,
          confirmationMedianTimePast: 600000000,
        ),
      ),
      isFalse,
    );
    expect(
      relative.blockingTimingActivation(
        _maturity(
          confirmations: 20,
          tipHeight: 100,
          medianTimePast: 600001023,
          confirmationMedianTimePast: 600000000,
        ),
      ),
      isA<BitcoinPolicyActivation>()
          .having(
            (activation) => activation.type,
            'type',
            BitcoinPolicyActivationType.relativeTime,
          )
          .having((activation) => activation.value, 'timestamp', 600001024),
    );
    expect(
      relative.timingIsSatisfied(
        _maturity(
          confirmations: 20,
          tipHeight: 100,
          medianTimePast: 600001024,
          confirmationMedianTimePast: 600000000,
        ),
      ),
      isTrue,
    );
  });
}

BitcoinPsbtReview _review({
  int sequence = 0xfffffffd,
  int lockTime = 0,
  int version = 2,
}) => BitcoinPsbtReview(
  transactionId: 'txid',
  inputs: [_input(sequence: sequence)],
  outputs: [_output(index: 0, amountSat: 9000)],
  feeSat: BigInt.from(1000),
  estimatedTransactionVsize: 100,
  lockTime: lockTime,
  version: version,
);

BitcoinPolicyMaturity _maturity({
  required int confirmations,
  required int tipHeight,
  int medianTimePast = 600000000,
  int confirmationMedianTimePast = 599990000,
}) => BitcoinPolicyMaturity(
  tipHeight: tipHeight,
  medianTimePast: medianTimePast,
  utxos: [
    BitcoinPolicyUtxoMaturity(
      outpoint: '00:0',
      keychain: BitcoinPolicyKeychain.external,
      amountSat: BigInt.from(10000),
      confirmations: confirmations,
      confirmationMedianTimePast: confirmationMedianTimePast,
    ),
  ],
);

BitcoinPsbtInputReview _input({
  String outpoint = '00:0',
  int sequence = 0xfffffffd,
  Set<String> signedDescriptorKeyIds = const {},
}) => BitcoinPsbtInputReview(
  outpoint: outpoint,
  amountSat: BigInt.zero,
  keychain: BitcoinPolicyKeychain.external,
  localDescriptorKeyIds: const {'key-local'},
  sequence: sequence,
  signedDescriptorKeyIds: signedDescriptorKeyIds,
);

BitcoinPsbtOutputReview _output({
  required int index,
  required int amountSat,
  bool isWalletOwned = false,
}) => BitcoinPsbtOutputReview(
  index: index,
  amountSat: BigInt.from(amountSat),
  address: 'tb1qoutput',
  scriptHex: '0014aa',
  isWalletOwned: isWalletOwned,
);
