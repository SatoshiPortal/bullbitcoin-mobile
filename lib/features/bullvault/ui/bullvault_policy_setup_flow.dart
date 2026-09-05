import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class BullVaultPolicySetupFlow {
  static Future<bool> execute(
    BuildContext context, {
    required BullVaultCreateResult result,
    required WalletSigner signer,
  }) async {
    final device = signer.signerDevice;
    if (device == null) {
      return await _confirmManualSetup(
            context,
            signerName: signer.displayFingerprint,
          ) ??
          false;
    }
    if (device.isLedger) {
      const facade = LedgerFacade();
      final registered = await context.pushNamed<bool>(
        facade.registerWalletPolicyRouteName,
        extra: RegisterLedgerWalletPolicyRequest(
          result.wallet,
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
        extra: RegisterBitBoxWalletPolicyRequest(
          result.wallet,
          signerId: signer.id,
        ),
      );
      return registered == true;
    }

    await context.pushNamed(
      SettingsRoute.walletRegistration.name,
      pathParameters: {'walletId': result.wallet.id},
      extra: WalletRegistrationRequest(
        wallet: result.wallet,
        signerId: signer.id,
      ),
    );
    if (!context.mounted) return false;
    return await _confirmManualSetup(context, signerName: device.displayName) ??
        false;
  }

  static Future<bool?> _confirmManualSetup(
    BuildContext context, {
    required String signerName,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.bullVaultConfirmAirgappedSetupTitle),
      content: Text(
        context.loc.bullVaultConfirmAirgappedSetupDescription(
          signerName.isEmpty ? context.loc.importWatchOnlyUnknown : signerName,
        ),
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
