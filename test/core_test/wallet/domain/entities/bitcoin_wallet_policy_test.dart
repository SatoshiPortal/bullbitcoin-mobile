import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BitcoinWalletPolicy maturity', () {
    test('rejects duplicate and out-of-range path choices', () {
      final policy = thresholdPolicy();

      expect(
        () => BitcoinPolicySelection(
          choices: const {
            'external:root': [0, 0],
          },
        ),
        throwsArgumentError,
      );

      final outOfRange = BitcoinPolicySelection(
        choices: const {
          'external:root': [0, 3],
          'internal:root': [0, 3],
        },
      );
      expect(() => policy.pathRequirements(outOfRange), throwsArgumentError);

      expect(
        BitcoinPolicySelection(
          choices: const {
            'external:root': [1, 0],
          },
        ).hasSameChoices(
          BitcoinPolicySelection(
            choices: const {
              'external:root': [0, 1],
            },
          ),
        ),
        isTrue,
      );
    });

    test('rejects different receive and change path selections', () {
      final policy = delayedPolicy(
        BitcoinRelativeTimelockPolicyNode(id: 'delay', value: 10),
      );
      final selection = BitcoinPolicySelection(
        choices: const {
          'external:root': [0],
          'internal:root': [1],
        },
      );

      expect(() => policy.buildPath(selection), throwsStateError);
    });

    test('tracks relative path maturity per UTXO', () {
      final policy = delayedPolicy(
        BitcoinRelativeTimelockPolicyNode(id: 'delay', value: 10),
      );
      final selector = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      final delayedSelection = policy.select(
        current: const BitcoinPolicySelection.empty(),
        requirement: selector,
        selectedIndices: const {1},
      );
      final maturity = BitcoinPolicyMaturity(
        tipHeight: 100,
        medianTimePast: 100000,
        utxos: [
          BitcoinPolicyUtxoMaturity(
            outpoint: 'external:0',
            keychain: BitcoinPolicyKeychain.external,
            amountSat: BigInt.from(1000),
            confirmations: 5,
          ),
          BitcoinPolicyUtxoMaturity(
            outpoint: 'internal:1',
            keychain: BitcoinPolicyKeychain.internal,
            amountSat: BigInt.from(2000),
            confirmations: 12,
          ),
        ],
      );

      final walletStatus = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: maturity,
      );
      final immatureCoinStatus = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: maturity,
        selectedOutpoints: const {'external:0'},
      );
      final path = policy.buildPath(delayedSelection, maturity: maturity);

      expect(walletStatus.available, isTrue);
      expect(walletStatus.availableAmountSat, BigInt.from(2000));
      expect(walletStatus.activatingAmountSat, BigInt.from(1000));
      expect(walletStatus.activation?.value, 5);
      expect(immatureCoinStatus.available, isFalse);
      expect(immatureCoinStatus.availableAmountSat, BigInt.zero);
      expect(immatureCoinStatus.activatingAmountSat, BigInt.from(1000));
      expect(
        immatureCoinStatus.activation?.type,
        BitcoinPolicyActivationType.relativeBlocks,
      );
      expect(immatureCoinStatus.activation?.value, 5);
      expect(
        policy.selectionIsAvailable(
          selection: delayedSelection,
          maturity: maturity,
        ),
        isTrue,
      );
      expect(
        policy.selectionIsAvailable(
          selection: delayedSelection,
          maturity: maturity,
          selectedOutpoints: const {'external:0'},
        ),
        isFalse,
      );
      expect(
        policy.selectionIsAvailable(
          selection: delayedSelection,
          maturity: maturity,
          selectedOutpoints: const {'internal:1', 'missing:2'},
        ),
        isFalse,
      );
      expect(path.eligibleExternalOutpoints, isEmpty);
      expect(path.eligibleInternalOutpoints, {'internal:1'});
    });

    test('selects the only currently available spending path', () {
      final policy = delayedPolicy(
        BitcoinRelativeTimelockPolicyNode(id: 'delay', value: 10),
      );
      BitcoinPolicyMaturity maturity(int confirmations) =>
          BitcoinPolicyMaturity(
            tipHeight: 100,
            medianTimePast: 100000,
            utxos: [
              BitcoinPolicyUtxoMaturity(
                outpoint: 'external:0',
                keychain: BitcoinPolicyKeychain.external,
                amountSat: BigInt.from(1000),
                confirmations: confirmations,
              ),
            ],
          );

      final onlyImmediate = policy.selectOnlyAvailablePaths(
        current: const BitcoinPolicySelection.empty(),
        maturity: maturity(5),
      );
      final multipleAvailable = policy.selectOnlyAvailablePaths(
        current: const BitcoinPolicySelection.empty(),
        maturity: maturity(12),
      );

      expect(policy.pathRequirements(onlyImmediate), isEmpty);
      expect(policy.pathRequirements(multipleAvailable), isNotEmpty);
    });

    test(
      'activates absolute paths for the whole wallet at the target block',
      () {
        final policy = delayedPolicy(
          BitcoinAbsoluteTimelockPolicyNode(
            id: 'delay',
            type: BitcoinAbsoluteTimelockType.blockHeight,
            value: 101,
          ),
        );
        final selector = policy
            .pathSelectors(const BitcoinPolicySelection.empty())
            .single;
        BitcoinPolicyMaturity maturity(int height) => BitcoinPolicyMaturity(
          tipHeight: height,
          medianTimePast: 100000,
          utxos: [
            BitcoinPolicyUtxoMaturity(
              outpoint: 'external:0',
              keychain: BitcoinPolicyKeychain.external,
              amountSat: BigInt.from(1000),
              confirmations: 20,
            ),
          ],
        );

        final before = policy.optionStatus(
          requirement: selector,
          optionIndex: 1,
          selection: const BitcoinPolicySelection.empty(),
          maturity: maturity(100),
        );
        final after = policy.optionStatus(
          requirement: selector,
          optionIndex: 1,
          selection: const BitcoinPolicySelection.empty(),
          maturity: maturity(101),
        );

        expect(before.available, isFalse);
        expect(
          before.activation?.type,
          BitcoinPolicyActivationType.absoluteBlock,
        );
        expect(before.activation?.value, 101);
        expect(after.available, isTrue);
      },
    );

    test('uses median time past for absolute time paths', () {
      final policy = delayedPolicy(
        BitcoinAbsoluteTimelockPolicyNode(
          id: 'delay',
          type: BitcoinAbsoluteTimelockType.timestamp,
          value: 100000,
        ),
      );
      final selector = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      BitcoinPolicyMaturity maturity(int medianTimePast) =>
          BitcoinPolicyMaturity(
            tipHeight: 100,
            medianTimePast: medianTimePast,
            utxos: [
              BitcoinPolicyUtxoMaturity(
                outpoint: 'external:0',
                keychain: BitcoinPolicyKeychain.external,
                amountSat: BigInt.from(1000),
                confirmations: 20,
              ),
            ],
          );

      final atTarget = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: maturity(100000),
      );
      final afterTarget = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: maturity(100001),
      );

      expect(atTarget.available, isFalse);
      expect(
        atTarget.activation?.type,
        BitcoinPolicyActivationType.absoluteTime,
      );
      expect(afterTarget.available, isTrue);
    });

    test('does not estimate absolute time activation without median time', () {
      final policy = delayedPolicy(
        BitcoinAbsoluteTimelockPolicyNode(
          id: 'delay',
          type: BitcoinAbsoluteTimelockType.timestamp,
          value: 100000,
        ),
      );
      final selector = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      final status = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: BitcoinPolicyMaturity(
          tipHeight: 100,
          medianTimePast: null,
          utxos: const [],
        ),
      );

      expect(status.available, isFalse);
      expect(status.activation, isNull);
    });

    test('uses each UTXO confirmation time for relative time paths', () {
      final policy = delayedPolicy(
        BitcoinRelativeTimelockPolicyNode(
          id: 'delay',
          type: BitcoinRelativeTimelockType.seconds,
          value: 512,
        ),
      );
      final selector = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      BitcoinPolicyMaturity maturity(int medianTimePast) =>
          BitcoinPolicyMaturity(
            tipHeight: 100,
            medianTimePast: medianTimePast,
            utxos: [
              BitcoinPolicyUtxoMaturity(
                outpoint: 'external:0',
                keychain: BitcoinPolicyKeychain.external,
                amountSat: BigInt.from(1000),
                confirmations: 20,
                confirmationMedianTimePast: 100000,
              ),
            ],
          );

      final before = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: maturity(100511),
      );
      final atTarget = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: maturity(100512),
      );

      expect(before.available, isFalse);
      expect(before.activation?.type, BitcoinPolicyActivationType.relativeTime);
      expect(before.activation?.value, 100512);
      expect(atTarget.available, isTrue);
    });

    test('keeps selected-input activation unknown when one is unknown', () {
      final policy = delayedPolicy(
        BitcoinRelativeTimelockPolicyNode(
          id: 'delay',
          type: BitcoinRelativeTimelockType.seconds,
          value: 512,
        ),
      );
      final selector = policy
          .pathSelectors(const BitcoinPolicySelection.empty())
          .single;
      final status = policy.optionStatus(
        requirement: selector,
        optionIndex: 1,
        selection: const BitcoinPolicySelection.empty(),
        maturity: BitcoinPolicyMaturity(
          tipHeight: 100,
          medianTimePast: 100000,
          utxos: [
            BitcoinPolicyUtxoMaturity(
              outpoint: 'external:0',
              keychain: BitcoinPolicyKeychain.external,
              amountSat: BigInt.from(1000),
              confirmations: 1,
              confirmationMedianTimePast: 100000,
            ),
            BitcoinPolicyUtxoMaturity(
              outpoint: 'external:1',
              keychain: BitcoinPolicyKeychain.external,
              amountSat: BigInt.from(2000),
              confirmations: 0,
            ),
          ],
        ),
        selectedOutpoints: const {'external:0', 'external:1'},
      );

      expect(status.available, isFalse);
      expect(status.activation, isNull);
      expect(status.activatingAmountSat, BigInt.zero);
    });

    test('calculates activation for the complete selected policy', () {
      final mandatoryDelay = policyWithRoot(
        BitcoinThresholdPolicyNode(
          id: 'and',
          threshold: 2,
          children: [
            BitcoinAbsoluteTimelockPolicyNode(
              id: 'delay',
              type: BitcoinAbsoluteTimelockType.blockHeight,
              value: 101,
            ),
            BitcoinThresholdPolicyNode(
              id: 'alternative',
              threshold: 1,
              requiresPath: true,
              children: [signaturePolicy('a'), signaturePolicy('b')],
            ),
          ],
        ),
      );
      final selection = BitcoinPolicySelection(
        choices: const {
          'external:root/1': [0],
          'internal:root/1': [0],
        },
      );

      expect(
        mandatoryDelay
            .nextActivation(selection: selection, maturity: maturityAt(1))
            ?.value,
        101,
      );

      final thresholdDelay = policyWithRoot(
        BitcoinThresholdPolicyNode(
          id: 'threshold',
          threshold: 2,
          children: [
            BitcoinRelativeTimelockPolicyNode(id: 'first', value: 5),
            BitcoinRelativeTimelockPolicyNode(id: 'second', value: 10),
            BitcoinRelativeTimelockPolicyNode(id: 'third', value: 20),
          ],
        ),
      );

      expect(
        thresholdDelay
            .nextActivation(
              selection: const BitcoinPolicySelection.empty(),
              maturity: maturityAt(0),
            )
            ?.value,
        10,
      );
    });
  });
}

BitcoinSignaturePolicyNode signaturePolicy(String id) =>
    BitcoinSignaturePolicyNode(
      id: id,
      key: BitcoinPolicyKey(
        kind: BitcoinPolicyKeyKind.fingerprint,
        value: '11111111',
      ),
    );

BitcoinWalletPolicy policyWithRoot(BitcoinPolicyNode root) {
  final spending = BitcoinSpendingPolicy(root: root, requiresPath: true);
  return BitcoinWalletPolicy(external: spending, internal: spending);
}

BitcoinPolicyMaturity maturityAt(int confirmations) => BitcoinPolicyMaturity(
  tipHeight: 100,
  medianTimePast: 100000,
  utxos: [
    BitcoinPolicyUtxoMaturity(
      outpoint: 'external:0',
      keychain: BitcoinPolicyKeychain.external,
      amountSat: BigInt.from(1000),
      confirmations: confirmations,
    ),
  ],
);

BitcoinWalletPolicy thresholdPolicy() {
  BitcoinPolicyNode root(String suffix) => BitcoinThresholdPolicyNode(
    id: 'root-$suffix',
    threshold: 2,
    requiresPath: true,
    children: [
      for (var index = 0; index < 3; index++)
        BitcoinSignaturePolicyNode(
          id: 'key-$index-$suffix',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.fingerprint,
            value: '0000000$index',
          ),
        ),
    ],
  );

  return BitcoinWalletPolicy(
    external: BitcoinSpendingPolicy(root: root('external'), requiresPath: true),
    internal: BitcoinSpendingPolicy(root: root('internal'), requiresPath: true),
  );
}

BitcoinWalletPolicy delayedPolicy(BitcoinPolicyNode timelock) {
  BitcoinPolicyNode root(String suffix) => BitcoinThresholdPolicyNode(
    id: 'root-$suffix',
    threshold: 1,
    requiresPath: true,
    children: [
      BitcoinSignaturePolicyNode(
        id: 'immediate-$suffix',
        key: BitcoinPolicyKey(
          kind: BitcoinPolicyKeyKind.fingerprint,
          value: '11111111',
        ),
      ),
      BitcoinThresholdPolicyNode(
        id: 'delayed-$suffix',
        threshold: 2,
        children: [
          timelock,
          BitcoinSignaturePolicyNode(
            id: 'recovery-$suffix',
            key: BitcoinPolicyKey(
              kind: BitcoinPolicyKeyKind.fingerprint,
              value: '22222222',
            ),
          ),
        ],
      ),
    ],
  );

  return BitcoinWalletPolicy(
    external: BitcoinSpendingPolicy(root: root('external'), requiresPath: true),
    internal: BitcoinSpendingPolicy(root: root('internal'), requiresPath: true),
  );
}
