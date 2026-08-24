import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('summarizes the resolved conditions of a nested policy', (
    tester,
  ) async {
    final policy = _policy();
    var selection = const BitcoinPolicySelection.empty();
    for (final selectedIndex in const [1, 1]) {
      selection = policy.select(
        current: selection,
        requirement: policy.pathRequirements(selection).first,
        selectedIndices: {selectedIndex},
      );
    }
    final state = SendState(
      bitcoinPolicySelection: selection,
      bitcoinSigningPlan: BitcoinSigningPlan.fromPolicy(
        policy: policy,
        selection: selection,
        signers: const [],
        inputKeychains: const {BitcoinPolicyKeychain.external},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              Text(describeSelectedBitcoinPolicyPath(context, null, state)),
        ),
      ),
    );

    final summary = tester.widget<Text>(find.byType(Text)).data!;
    expect(summary, contains('After block 500'));
    expect(summary, contains('Wait 20 blocks'));
    expect(summary, contains('2 of 3 signatures required'));
    expect(summary, isNot(contains('Choose')));
  });
}

BitcoinWalletPolicy _policy() {
  BitcoinPolicyKey key(String fingerprint) => BitcoinPolicyKey(
    kind: BitcoinPolicyKeyKind.fingerprint,
    value: fingerprint,
  );

  BitcoinPolicyNode root() => BitcoinThresholdPolicyNode(
    id: 'root',
    threshold: 1,
    requiresPath: true,
    children: [
      BitcoinSignaturePolicyNode(id: 'immediate', key: key('aaaaaaaa')),
      BitcoinThresholdPolicyNode(
        id: 'outer-all',
        threshold: 2,
        requiresPath: true,
        children: [
          BitcoinAbsoluteTimelockPolicyNode(
            id: 'absolute',
            type: BitcoinAbsoluteTimelockType.blockHeight,
            value: 500,
          ),
          BitcoinThresholdPolicyNode(
            id: 'nested-choice',
            threshold: 1,
            requiresPath: true,
            children: [
              BitcoinSignaturePolicyNode(id: 'alternate', key: key('bbbbbbbb')),
              BitcoinThresholdPolicyNode(
                id: 'inner-all',
                threshold: 2,
                requiresPath: true,
                children: [
                  BitcoinRelativeTimelockPolicyNode(id: 'relative', value: 20),
                  BitcoinThresholdPolicyNode(
                    id: 'multisig',
                    threshold: 2,
                    children: [
                      BitcoinSignaturePolicyNode(
                        id: 'signer-a',
                        key: key('aaaaaaaa'),
                      ),
                      BitcoinSignaturePolicyNode(
                        id: 'signer-b',
                        key: key('bbbbbbbb'),
                      ),
                      BitcoinSignaturePolicyNode(
                        id: 'signer-c',
                        key: key('cccccccc'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return BitcoinWalletPolicy(
    external: BitcoinSpendingPolicy(root: root(), requiresPath: true),
    internal: BitcoinSpendingPolicy(root: root(), requiresPath: true),
  );
}
