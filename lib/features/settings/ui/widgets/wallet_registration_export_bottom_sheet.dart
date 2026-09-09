import 'dart:io';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_registration_qr.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class WalletRegistrationExportBottomSheet extends StatelessWidget {
  final WalletRegistrationOption option;

  const WalletRegistrationExportBottomSheet({super.key, required this.option});

  static Future<void> show(
    BuildContext context,
    WalletRegistrationOption option,
  ) => BullBottomSheet.show(
    context: context,
    child: WalletRegistrationExportBottomSheet(option: option),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.loc.walletRegistrationDeviceAction(
                    option.device.displayName,
                  ),
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
          const Gap(20),
          switch (option) {
            final AvailableWalletRegistration available => _AvailableExport(
              option: available,
            ),
            ConnectedWalletRegistration() => const SizedBox.shrink(),
            final UnavailableWalletRegistration unavailable => BullInfoCard(
              description: _unavailableDescription(context, unavailable),
              tagColor: context.appColors.error,
              bgColor: context.appColors.errorContainer,
            ),
          },
        ],
      ),
    );
  }
}

class _AvailableExport extends StatelessWidget {
  final AvailableWalletRegistration option;

  const _AvailableExport({required this.option});

  @override
  Widget build(BuildContext context) {
    final hasQr = option.qrEncoding != WalletRegistrationQrEncoding.none;
    final hasNfc =
        option.device == SignerDeviceEntity.coldcardQ ||
        option.device == SignerDeviceEntity.coldcardMk4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasQr
              ? context.loc.walletRegistrationScanDescription(
                  option.device.displayName,
                )
              : context.loc.walletRegistrationFileDescription(
                  option.device.displayName,
                ),
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(20),
        if (hasQr) ...[
          Center(
            child: WalletRegistrationQr(
              data: option.qrData,
              encoding: option.qrEncoding,
            ),
          ),
          const Gap(24),
        ],
        CopyInput(
          text: option.fileData,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          canShowValueModal: true,
          modalTitle: context.loc.walletRegistrationDeviceAction(
            option.device.displayName,
          ),
        ),
        const Gap(16),
        if (hasNfc) ...[
          BullButton.big(
            label: context.loc.walletRegistrationShareNfc,
            onPressed: () => NfcBottomSheet.showWriteNfc(
              context: context,
              title: context.loc.walletRegistrationShareNfcTitle(
                option.device.displayName,
              ),
              data: option.fileData,
              onSuccess: () {},
            ),
            bgColor: context.appColors.surface,
            textColor: context.appColors.secondary,
            iconData: Icons.nfc,
            outlined: true,
          ),
          const Gap(16),
        ],
        Builder(
          builder: (buttonContext) => BullButton.big(
            label: context.loc.walletRegistrationShareFile,
            onPressed: () => _shareFile(buttonContext),
            bgColor: context.appColors.surface,
            textColor: context.appColors.secondary,
            iconData: Icons.share_outlined,
            outlined: true,
          ),
        ),
        const Gap(20),
        BullInfoCard(
          description: context.loc.walletRegistrationReviewNotice,
          tagColor: context.appColors.secondary,
          bgColor: context.appColors.onSecondary,
        ),
      ],
    );
  }

  Future<void> _shareFile(BuildContext context) async {
    Directory? exportDirectory;
    try {
      final box = context.findRenderObject() as RenderBox;
      final origin = box.localToGlobal(Offset.zero) & box.size;
      final temporaryDirectory = await getTemporaryDirectory();
      exportDirectory = await temporaryDirectory.createTemp(
        'bull-wallet-registration-',
      );
      final file = File('${exportDirectory.path}/${option.fileName}');
      await file.writeAsString(option.fileData, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: option.fileName,
          sharePositionOrigin: origin,
        ),
      );
    } on Exception {
      if (context.mounted) {
        BullSnackBar.show(context, message: context.loc.oopsSomethingWentWrong);
      }
    } finally {
      try {
        if (exportDirectory != null && await exportDirectory.exists()) {
          await exportDirectory.delete(recursive: true);
        }
      } on Exception {
        // Temporary file cleanup is best effort.
      }
    }
  }
}

String _unavailableDescription(
  BuildContext context,
  UnavailableWalletRegistration option,
) => switch (option.reason) {
  WalletRegistrationUnavailableReason.unsupportedPolicy =>
    context.loc.walletRegistrationUnsupportedPolicy(option.device.displayName),
  WalletRegistrationUnavailableReason.unsupportedKeyOrigins =>
    context.loc.walletRegistrationUnsupportedKeyOrigins(
      option.device.displayName,
    ),
};
