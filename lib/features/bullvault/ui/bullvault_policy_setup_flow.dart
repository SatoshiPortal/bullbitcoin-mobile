import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_registration_name_dialog.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar, Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

abstract final class BullVaultPolicySetupFlow {
  static Future<bool> execute(
    BuildContext context, {
    required BullVaultCreateResult result,
    required WalletSigner signer,
    required Future<BullVaultCreateResult?> Function(String name)
    updateRegistrationName,
  }) async {
    final device = signer.signerDevice;
    if (device == null) {
      return await _confirmManualSetup(
            context,
            signerName: signer.displayFingerprint,
            descriptor: result.policy.descriptor,
          ) ??
          false;
    }
    final name = await promptBullVaultRegistrationName(
      context,
      signer: signer,
      fallbackName: result.wallet.label ?? context.loc.bullVaultTitle,
    );
    if (name == null || !context.mounted) return false;
    final updated = await updateRegistrationName(name);
    if (updated == null || !context.mounted) return false;
    final wallet = updated.wallet;
    if (device.isLedger) {
      const facade = LedgerFacade();
      final registered = await context.pushNamed<bool>(
        facade.registerWalletPolicyRouteName,
        extra: RegisterLedgerWalletPolicyRequest(
          wallet,
          requestedDeviceType: device,
          signerId: signer.id,
        ),
      );
      return registered == true;
    }
    if (device.isBitBox) {
      const facade = BitBoxFacade();
      final registered = await context.pushNamed<bool>(
        facade.registerWalletPolicyRouteName,
        extra: RegisterBitBoxWalletPolicyRequest(wallet, signerId: signer.id),
      );
      return registered == true;
    }

    await context.pushNamed(
      SettingsRoute.walletRegistration.name,
      pathParameters: {'walletId': wallet.id},
      extra: WalletRegistrationRequest(wallet: wallet, signerId: signer.id),
    );
    if (!context.mounted) return false;
    return await _confirmManualSetup(
          context,
          signerName: device.displayName,
          descriptor: result.policy.descriptor,
        ) ??
        false;
  }

  /// The signer has no integration of its own, so the policy is handed over
  /// by hand: copy the descriptor or scan it, register it on the device, then
  /// confirm.
  static Future<bool?> _confirmManualSetup(
    BuildContext context, {
    required String signerName,
    required String descriptor,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.bullVaultConfirmAirgappedSetupTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.bullVaultConfirmAirgappedSetupDescription(
              signerName.isEmpty
                  ? context.loc.importWatchOnlyUnknown
                  : signerName,
            ),
          ),
          const Gap(16),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(context.loc.walletBackupVaultsCopyDescriptor),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: descriptor));
              if (dialogContext.mounted) {
                BullSnackBar.show(
                  dialogContext,
                  message: context.loc.walletBackupVaultsDescriptorCopied,
                );
              }
            },
          ),
          const Gap(8),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code),
            label: Text(context.loc.bullVaultShowDescriptorQr),
            onPressed: () => showDialog<void>(
              context: dialogContext,
              builder: (_) => Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QrDisplayWidget(data: descriptor),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => dialogContext.pop(false),
          child: Text(context.loc.cancel),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(true),
          child: Text(context.loc.confirmButton),
        ),
      ],
    ),
  );
}
