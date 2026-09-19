import 'dart:io';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_policy_panel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../../test/features/bullvault/bullvault_test_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'POLICY_CAPTURE_PHASE',
    defaultValue: 'before',
  );
  testWidgets('BV04 policy facts render without reading a local seed', (
    tester,
  ) async {
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
      id: 'signature-$i',
      key: BitcoinPolicyKey(
        kind: .descriptorKey,
        value: signers[i].descriptorKeys.single.id,
      ),
    );
    final root = BitcoinThresholdPolicyNode(
      id: 'paths',
      threshold: 1,
      requiresPath: true,
      children: [
        BitcoinThresholdPolicyNode(
          id: 'two-of-three',
          threshold: 2,
          children: [signature(0), signature(1), signature(2)],
        ),
        BitcoinThresholdPolicyNode(
          id: 'absolute',
          threshold: 2,
          children: [
            BitcoinAbsoluteTimelockPolicyNode(
              id: 'date',
              type: .timestamp,
              value:
                  DateTime.utc(2027, 1, 2, 14, 5, 6).millisecondsSinceEpoch ~/
                  1000,
            ),
            signature(0),
          ],
        ),
        BitcoinThresholdPolicyNode(
          id: 'relative',
          threshold: 2,
          children: [
            BitcoinRelativeTimelockPolicyNode(id: 'blocks', value: 144),
            signature(1),
          ],
        ),
      ],
    );
    final policy = BitcoinWalletPolicy(
      external: BitcoinSpendingPolicy(root: root, requiresPath: true),
      internal: BitcoinSpendingPolicy(root: root, requiresPath: true),
    );
    final directory = await getTemporaryDirectory();
    for (final dark in [false, true]) {
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(
            dark ? AppThemeType.dark : AppThemeType.light,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('BullVault policy')),
            body: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              child: BullVaultPolicyDetails(
                inspection: inspection,
                policy: policy,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!dark) await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      for (final bottom in [false, true]) {
        if (bottom) scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final name =
            'policy-$phase-${dark ? 'dark' : 'light'}-${bottom ? 'bottom' : 'top'}';
        final bytes = await binding.takeScreenshot(name);
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
    }
    const holdSeconds = int.fromEnvironment('POLICY_CAPTURE_HOLD_SECONDS');
    await Future<void>.delayed(Duration(seconds: holdSeconds));
  });
}
