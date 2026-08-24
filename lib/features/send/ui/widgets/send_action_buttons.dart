import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConfirmSendButton extends StatelessWidget {
  const ConfirmSendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.hasFinalizedBitcoinTransaction,
    );
    final disableSendButton = context.select(
      (SendCubit cubit) => cubit.state.disableConfirmSend,
    );
    return BBButton.big(
      label: hasFinalizedTx
          ? context.loc.sendBroadcastTransaction
          : context.loc.sendConfirm,
      onPressed: () {
        context.read<SendCubit>().onConfirmTransactionClicked();
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
      disabled: disableSendButton,
    );
  }
}

class BitcoinSigningSection extends StatelessWidget {
  const BitcoinSigningSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final plan = state.bitcoinSigningPlan;
    if (plan == null) return const SizedBox.shrink();
    final signingComplete = state.hasFinalizedBitcoinTransaction;
    final visibleSigners = signingComplete
        ? const <WalletSigner>[]
        : plan.eligibleSigners;
    final hasConnectedDeviceSigner = visibleSigners.any(
      (signer) =>
          !state.isBitcoinSignerSigned(signer) &&
          (state.selectedWallet?.supportsWalletPolicySigner(signer) ?? false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          context.loc.sendSigningTitle,
          style: context.font.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          color: context.appColors.secondary,
        ),
        const Gap(4),
        BBText(
          signingComplete
              ? context.loc.sendSigningReady
              : context.loc.sendSignersNeeded(plan.signersNeeded),
          style: context.font.bodySmall,
          color: context.appColors.textMuted,
        ),
        const Gap(12),
        for (final (index, signer) in visibleSigners.indexed) ...[
          _BitcoinSignerTile(signer: signer),
          if (index != visibleSigners.length - 1) const Gap(8),
        ],
        if (hasConnectedDeviceSigner) ...[
          const Gap(12),
          ShowPsbtButton(
            outlined: true,
            disabled:
                state.signingTransaction ||
                state.persistingPendingTransaction ||
                state.isSigningConflict ||
                !state.isSigningPolicyReady,
          ),
        ],
      ],
    );
  }
}

class _BitcoinSignerTile extends StatelessWidget {
  final WalletSigner signer;

  const _BitcoinSignerTile({required this.signer});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final signed = state.isBitcoinSignerSigned(signer);
    final satisfied = state.bitcoinSigningPlan?.isSatisfied ?? false;
    final canAct =
        !signed &&
        !satisfied &&
        !state.signingTransaction &&
        !state.persistingPendingTransaction &&
        !state.isSigningConflict &&
        state.isSigningPolicyReady;
    final signerName = signer.signer == SignerEntity.local
        ? context.loc.importWatchOnlyBullMobileDevice
        : signer.signerDevice?.displayName ??
              context.loc.walletDetailsExternalSignerLabel;
    final fingerprint = signer.displayFingerprint;
    final wallet = state.selectedWallet;
    final usesConnectedDevice =
        wallet?.supportsWalletPolicySigner(signer) ?? false;

    return BorderedTappableTile(
      onTap: canAct ? () => _sign(context) : null,
      child: Row(
        children: [
          Icon(
            signed ? Icons.check_circle_outline : Icons.key_outlined,
            color: signed
                ? context.appColors.primary
                : context.appColors.secondary,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  signerName,
                  style: context.font.bodyMedium,
                  color: context.appColors.secondary,
                ),
                if (fingerprint.isNotEmpty)
                  BBText(
                    fingerprint,
                    style: context.font.bodySmall,
                    color: context.appColors.textMuted,
                  ),
              ],
            ),
          ),
          const Gap(12),
          BBText(
            signed
                ? context.loc.sendSignerSigned
                : signer.signer == SignerEntity.local
                ? context.loc.sendSignerSign
                : usesConnectedDevice
                ? context.loc.sendSignerSign
                : context.loc.psbtFlowSharePsbt,
            style: context.font.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            color: canAct
                ? context.appColors.primary
                : context.appColors.textMuted,
          ),
        ],
      ),
    );
  }

  Future<void> _sign(BuildContext context) async {
    if (signer.signer == SignerEntity.local) {
      await context.read<SendCubit>().signBitcoinWithBull(signer);
      return;
    }

    final state = context.read<SendCubit>().state;
    final wallet = state.selectedWallet;
    final psbt = state.unsignedPsbt;
    if (wallet != null &&
        psbt != null &&
        wallet.supportsWalletPolicySigner(signer) &&
        signer.signerDevice?.isLedger == true) {
      const facade = LedgerFacade();
      final result = await context.pushNamed<String>(
        facade.signWalletPolicyRouteName,
        extra: SignLedgerWalletPolicyRequest(
          wallet: wallet,
          signerId: signer.id,
          psbt: psbt,
          requestedDeviceType: signer.signerDevice!,
        ),
      );
      if (result != null && context.mounted) {
        await context.read<SendCubit>().applyExternalBitcoinPsbt(result);
      }
      return;
    }
    if (wallet != null &&
        psbt != null &&
        wallet.supportsWalletPolicySigner(signer) &&
        signer.signerDevice?.isBitBox == true) {
      const facade = BitBoxFacade();
      final result = await context.pushNamed<String>(
        facade.signWalletPolicyRouteName,
        extra: SignBitBoxWalletPolicyRequest(
          wallet: wallet,
          signerId: signer.id,
          psbt: psbt,
        ),
      );
      if (result != null && context.mounted) {
        await context.read<SendCubit>().applyExternalBitcoinPsbt(result);
      }
      return;
    }

    final result = await context.pushNamed<String>(
      PsbtFlowRoutes.show.name,
      extra: (
        psbt: context.read<SendCubit>().state.unsignedPsbt,
        signerDevice: signer.signerDevice,
      ),
    );
    if (result != null && context.mounted) {
      await context.read<SendCubit>().applyExternalBitcoinSigningResult(result);
    }
  }
}

class ShowPsbtButton extends StatelessWidget {
  final WalletSigner? signer;
  final bool outlined;
  final bool disabled;

  const ShowPsbtButton({
    super.key,
    this.signer,
    this.outlined = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    return BBButton.big(
      label: context.loc.psbtFlowSharePsbt,
      onPressed: () async {
        final result = await context.pushNamed<String>(
          PsbtFlowRoutes.show.name,
          extra: (psbt: unsignedPsbt, signerDevice: signer?.signerDevice),
        );
        if (result != null && context.mounted) {
          await context.read<SendCubit>().applyExternalBitcoinSigningResult(
            result,
          );
        }
      },
      bgColor: outlined
          ? context.appColors.surface
          : context.appColors.secondary,
      textColor: outlined
          ? context.appColors.secondary
          : context.appColors.onSecondary,
      outlined: outlined,
      disabled: disabled || unsignedPsbt == null,
    );
  }
}

class SignLedgerButton extends StatelessWidget {
  final WalletSigner? signer;

  const SignLedgerButton({super.key, this.signer});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );
    final derivationPath = signer?.descriptorKeys.length == 1
        ? signer!.descriptorKeys.single.derivationPath
        : null;
    final deviceType = signer?.signerDevice;
    final scriptType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.scriptType,
    );

    return BBButton.big(
      label: context.loc.sendSignWithLedger,
      onPressed: () async {
        if (unsignedPsbt == null) return;

        final result = await context.pushNamed<String>(
          LedgerRoute.ledgerSignTransaction.name,
          extra: LedgerRouteParams(
            psbt: unsignedPsbt,
            derivationPath: derivationPath,
            requestedDeviceType: deviceType,
            scriptType: scriptType,
          ),
        );

        if (result != null && context.mounted) {
          final accepted = await context
              .read<SendCubit>()
              .applyExternalBitcoinSigningResult(result);
          if (accepted && context.mounted) {
            SnackBarUtils.showSnackBar(
              context,
              context.loc.sendTransactionSignedLedger,
            );
          }
        }
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}

class SignBitBoxButton extends StatelessWidget {
  final WalletSigner? signer;

  const SignBitBoxButton({super.key, this.signer});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );
    final derivationPath = signer?.descriptorKeys.length == 1
        ? signer!.descriptorKeys.single.derivationPath
        : null;
    final deviceType = signer?.signerDevice;
    final scriptType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.scriptType,
    );

    return BBButton.big(
      label: context.loc.sendSignWithBitBox,
      onPressed: () async {
        if (unsignedPsbt == null) return;

        final result = await context.pushNamed<String>(
          BitBoxRoute.bitboxSignTransaction.name,
          extra: BitBoxRouteParams(
            psbt: unsignedPsbt,
            derivationPath: derivationPath,
            requestedDeviceType: deviceType,
            scriptType: scriptType,
          ),
        );

        if (result != null && context.mounted) {
          await context.read<SendCubit>().applyExternalBitcoinSigningResult(
            result,
          );
        }
      },
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}
