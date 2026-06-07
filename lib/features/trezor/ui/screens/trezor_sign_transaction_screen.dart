import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_sign_transaction_cubit.dart';
import 'package:bb_mobile/features/trezor/ui/trezor_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Sign a PSBT on a connected Trezor.
///
/// Flow:
///   1. User taps "Start Signing" → app launches Trezor Suite via deeplink.
///   2. User reviews the transaction (destination, amount, fee) in Trezor
///      Suite and confirms on device.
///   3. On confirmation: pop back to the send flow with the broadcast-ready
///      signed-tx hex; the `SignTrezorButton` caller shows the success
///      snackbar and forwards the hex to `SendCubit.updateSignedBitcoinTx`.
///   4. On rejection / timeout: snackbar + inline error + Try Again.
class TrezorSignTransactionScreen extends StatelessWidget {
  final TrezorSignTransactionRouteParams params;
  const TrezorSignTransactionScreen({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrezorSignTransactionCubit>(
      create: (_) => locator<TrezorSignTransactionCubit>(),
      child: _SignTransactionView(params: params),
    );
  }
}

class _SignTransactionView extends StatelessWidget {
  final TrezorSignTransactionRouteParams params;
  const _SignTransactionView({required this.params});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Sign Transaction',
          color: context.appColors.background,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          BlocConsumer<
            TrezorSignTransactionCubit,
            TrezorOperationState<String>
          >(
            listener: (context, state) {
              if (state.isSuccess && state.result != null) {
                context.pop(state.result as String);
              } else if (state.isError) {
                SnackBarUtils.showSnackBar(
                  context,
                  state.errorMessage ?? 'Signing failed',
                );
              }
            },
            builder: (context, state) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Center(
                  child: Column(
                    children: [
                      const Gap(32),
                      _buildMainContent(context, state),
                      const Gap(32),
                      _buildActionButtons(context, state),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  // ───────────────────────── Sub-builders ─────────────────────────

  Widget _buildMainContent(BuildContext context, TrezorOperationState state) {
    return Column(
      children: [
        _buildIconForState(context, state),
        const Gap(24),
        BBText(
          _getMainTextForState(state),
          textAlign: TextAlign.center,
          style: context.font.bodyLarge,
        ),
        const Gap(16),
        BBText(
          _getSubTextForState(state),
          textAlign: TextAlign.center,
          color: context.appColors.textMuted,
          style: context.font.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildIconForState(BuildContext context, TrezorOperationState state) {
    if (state.isInitial) {
      return Icon(
        Icons.memory_outlined,
        size: 60,
        color: context.appColors.primary,
      );
    }
    if (state.isLaunching || state.isWaiting) {
      return SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(
          color: context.appColors.primary,
          strokeWidth: 3,
        ),
      );
    }
    if (state.isProcessing) {
      return Icon(Icons.edit, size: 80, color: context.appColors.primary);
    }
    if (state.isError) {
      return Icon(Icons.error, size: 80, color: context.appColors.error);
    }
    // Success path: the listener pops within the same frame.
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons(BuildContext context, TrezorOperationState state) {
    return Column(
      children: [
        if (state.isInitial)
          BBButton.big(
            onPressed: () => _onStartSigning(context),
            label: 'Start Signing',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        if (state.isError)
          BBButton.big(
            onPressed: () => context.read<TrezorSignTransactionCubit>().reset(),
            label: 'Try Again',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
      ],
    );
  }

  // ───────────────────────── Helpers ─────────────────────────

  // TODO: localize all of these once ARB keys are added.

  String _getMainTextForState(TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return 'Confirm in Trezor Suite';
    }
    if (state.isProcessing) return 'Signing Transaction';
    if (state.isError) return 'Signing Failed';
    return 'Sign Transaction';
  }

  String _getSubTextForState(TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return 'Your Trezor device will show the transaction details. '
          'Review the destination, amount, and fee, then confirm '
          'on the device.';
    }
    if (state.isProcessing) {
      return "You'll be redirected back to your wallet…";
    }
    if (state.isError) {
      return state.errorMessage ?? 'Tap Try Again to start over.';
    }
    return 'Tap "Start Signing" to review and confirm the transaction '
        'on your Trezor device.';
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _onStartSigning(BuildContext context) async {
    try {
      await context.read<TrezorSignTransactionCubit>().sign(
        psbt: params.psbt,
        isTestnet: params.isTestnet,
        scriptType: params.scriptType,
      );
    } catch (_) {
      // Cubit already emitted error state; listener shows snackbar.
    }
  }
}
