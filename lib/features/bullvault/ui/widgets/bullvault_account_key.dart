import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class BullVaultAccountKey extends StatelessWidget {
  final WalletDescriptorKey accountKey;
  const BullVaultAccountKey({super.key, required this.accountKey});

  String get _expression {
    final key = accountKey;
    final path = key.derivationPath;
    if (key.masterFingerprint.isEmpty || path == null || path.isEmpty) {
      return key.xpub;
    }
    if (path == 'm') {
      return '[${key.masterFingerprint.toLowerCase()}]${key.xpub}';
    }
    return Bip48Derivation.accountKeyExpression(
      masterFingerprint: key.masterFingerprint,
      derivationPath: path,
      xpub: key.xpub,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.loc.importWatchOnlyExtendedPublicKey,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ),
          IconButton(
            tooltip: context.loc.receiveQRCode,
            icon: const Icon(Icons.qr_code),
            onPressed: () => BlurredDialog.show<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.loc.importWatchOnlyExtendedPublicKey),
                content: SizedBox(
                  width: 300,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrDisplayWidget(data: _expression),
                        const Gap(16),
                        CopyInput(text: _expression),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.loc.closeDialogButton),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const Gap(4),
      CopyInput(text: accountKey.xpub, clipboardText: _expression),
    ],
  );
}
