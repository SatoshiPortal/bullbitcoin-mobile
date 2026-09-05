import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class WalletDescriptorDetailsBottomSheet extends StatelessWidget {
  final Wallet wallet;

  const WalletDescriptorDetailsBottomSheet({super.key, required this.wallet});

  static Future<void> show(BuildContext context, Wallet wallet) =>
      BlurredBottomSheet.show(
        context: context,
        child: WalletDescriptorDetailsBottomSheet(wallet: wallet),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: BBText(
                  context.loc.walletDetailsDescriptorLabel,
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
          const Gap(24),
          _DescriptorField(
            label: context.loc.walletDetailsDescriptorLabel,
            descriptor: wallet.publicDescriptor,
          ),
        ],
      ),
    );
  }
}

class _DescriptorField extends StatelessWidget {
  final String label;
  final String descriptor;

  const _DescriptorField({required this.label, required this.descriptor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        CopyInput(
          text: descriptor,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          canShowValueModal: true,
          modalTitle: label,
        ),
      ],
    );
  }
}
