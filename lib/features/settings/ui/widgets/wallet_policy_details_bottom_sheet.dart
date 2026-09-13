import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_policy_view.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, Gap;
import 'package:flutter/material.dart';

class WalletPolicyDetailsBottomSheet extends StatelessWidget {
  final Wallet wallet;
  final BitcoinWalletPolicy policy;

  const WalletPolicyDetailsBottomSheet({
    super.key,
    required this.wallet,
    required this.policy,
  });

  static Future<void> show(
    BuildContext context, {
    required Wallet wallet,
    required BitcoinWalletPolicy policy,
  }) => BlurredBottomSheet.show(
    context: context,
    child: WalletPolicyDetailsBottomSheet(wallet: wallet, policy: policy),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: BullText(
                context.loc.walletDetailsSpendingConditionsLabel,
                style: context.font.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: context.loc.closeDialogButton,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const Gap(16),
        WalletPolicyDetails(wallet: wallet, policy: policy),
      ],
    ),
  );
}
