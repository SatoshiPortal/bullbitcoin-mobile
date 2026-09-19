import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_policy_panel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../bullvault_test_fixture.dart';

void main() {
  final loc = AppLocalizationsEn();
  final fixture = testBullVaultCreateResult(includesInheritance: true);
  final source = fixture.record.recoveryPackage.policy;
  final signers = [
    for (final key in [
      source.everydayKey,
      source.coldKey,
      source.inheritanceKey!,
    ])
      WalletSigner(
        id: key.accountKey.signerId,
        signer: SignerEntity.none,
        signerDevice: null,
        descriptorKeys: [key.accountKey],
      ),
  ];
  final inspection = BullVaultInspection(
    fixture.record,
    fixture.wallet.copyWith(signers: signers),
    {
      signers[0].descriptorKeys.single.id: .available,
      signers[1].descriptorKeys.single.id: .external,
      signers[2].descriptorKeys.single.id: .unavailable,
    },
  );
  BitcoinSignaturePolicyNode signature(int i) => BitcoinSignaturePolicyNode(
    id: 'sig-$i',
    key: BitcoinPolicyKey(
      kind: .descriptorKey,
      value: signers[i].descriptorKeys.single.id,
    ),
  );
  Future<void> pump(
    WidgetTester tester,
    BitcoinPolicyNode root, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(
          dark ? AppThemeType.dark : AppThemeType.light,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BullVaultPolicyDetails(
              inspection: inspection,
              policy: BitcoinWalletPolicy(
                external: BitcoinSpendingPolicy(root: root, requiresPath: true),
                internal: BitcoinSpendingPolicy(root: root, requiresPath: true),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shared renderer keeps the threshold, all keys and verified access',
    (tester) async {
      final rule = BitcoinThresholdPolicyNode(
        id: 'two-of-three',
        threshold: 2,
        children: [signature(0), signature(1), signature(2)],
      );
      for (final dark in [false, true]) {
        await pump(tester, rule, dark: dark);
        expect(find.byType(WalletPolicyDetailsContent), findsOneWidget);
        expect(
          find.text(loc.walletPolicySignaturesRequired(2, 3)),
          findsOneWidget,
        );
        for (final signer in signers) {
          expect(
            find.textContaining(signer.displayFingerprint),
            findsOneWidget,
          );
        }
        expect(find.text(loc.bullVaultKeyOnDevice), findsOneWidget);
        expect(find.text(loc.bullVaultKeyExternal), findsOneWidget);
        expect(find.text(loc.walletDetailsUnavailableLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'absolute and mixed conditions retain their exact block height and required conditions',
    (tester) async {
      final clock = BitcoinAbsoluteTimelockPolicyNode(
        id: 'clock',
        type: .blockHeight,
        value: 900000,
      );
      await pump(
        tester,
        BitcoinThresholdPolicyNode(
          id: 'timed',
          threshold: 2,
          children: [clock, signature(0)],
        ),
      );
      expect(
        find.text(loc.walletDetailsAbsoluteBlockCondition(900000)),
        findsOneWidget,
      );
      expect(find.text('From the start'), findsNothing);
      expect(find.text(loc.bullVaultKeyOnDevice), findsOneWidget);
      await pump(
        tester,
        BitcoinThresholdPolicyNode(
          id: 'mixed',
          threshold: 3,
          children: [
            clock,
            signature(0),
            BitcoinHashlockPolicyNode(id: 'hash', type: .sha256, hash: 'ab'),
          ],
        ),
      );
      expect(find.text('From the start'), findsNothing);
      expect(find.text(loc.walletDetailsAllConditionsRequired), findsOneWidget);
      expect(
        find.text(loc.walletDetailsAbsoluteBlockCondition(900000)),
        findsOneWidget,
      );
      expect(find.text(loc.walletPolicyHashPreimage), findsOneWidget);
    },
  );
  testWidgets(
    'relative and alternative conditions are never presented as available from start',
    (tester) async {
      final clock = BitcoinRelativeTimelockPolicyNode(
        id: 'relative',
        value: 144,
      );
      await pump(
        tester,
        BitcoinThresholdPolicyNode(
          id: 'relative-and',
          threshold: 2,
          children: [clock, signature(0)],
        ),
      );
      expect(
        find.text(loc.walletDetailsRelativeBlocksCondition(144)),
        findsOneWidget,
      );
      expect(find.text('From the start'), findsNothing);
      await pump(
        tester,
        BitcoinThresholdPolicyNode(
          id: 'either',
          threshold: 1,
          children: [
            BitcoinAbsoluteTimelockPolicyNode(
              id: 'absolute',
              type: .blockHeight,
              value: 900000,
            ),
            signature(0),
          ],
        ),
      );
      expect(
        find.text(loc.walletDetailsCompleteConditions(1, 2)),
        findsOneWidget,
      );
      expect(
        find.text(loc.walletDetailsAbsoluteBlockCondition(900000)),
        findsOneWidget,
      );
      expect(find.text('From the start'), findsNothing);
    },
  );
  testWidgets('absolute timestamps retain explicit UTC and nonzero seconds', (
    tester,
  ) async {
    for (final second in [0, 6]) {
      final date = DateTime.utc(2027, 1, 2, 14, 5, second);
      await pump(
        tester,
        BitcoinThresholdPolicyNode(
          id: 'dated',
          threshold: 2,
          children: [
            BitcoinAbsoluteTimelockPolicyNode(
              id: 'clock',
              type: .timestamp,
              value: date.millisecondsSinceEpoch ~/ 1000,
            ),
            signature(0),
          ],
        ),
      );
      final stamp = second == 0
          ? 'Jan 2, 2027 14:05 UTC'
          : 'Jan 2, 2027 14:05:06 UTC';
      expect(
        find.text(loc.walletDetailsAbsoluteTimeCondition(stamp)),
        findsOneWidget,
      );
    }
  });
}
