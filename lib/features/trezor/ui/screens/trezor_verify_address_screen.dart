import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_verify_address_cubit.dart';
import 'package:bb_mobile/features/trezor/ui/trezor_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Verify a Bitcoin receive address on a connected Trezor.
///
/// Flow:
///   1. Show the chunked address in-app.
///   2. User taps "Verify Address" → app launches Trezor Suite via deeplink.
///   3. User compares the address Suite shows against the in-app display
///      and confirms in Suite (and on-device for newer Trezors).
///   4. On confirmation: snackbar + pop back to Receive.
///   5. On rejection / timeout: inline error + Try Again.
class TrezorVerifyAddressScreen extends StatelessWidget {
  final TrezorVerifyAddressRouteParams params;
  const TrezorVerifyAddressScreen({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrezorVerifyAddressCubit>(
      create: (_) => locator<TrezorVerifyAddressCubit>(),
      child: _VerifyAddressView(params: params),
    );
  }
}

class _VerifyAddressView extends StatelessWidget {
  final TrezorVerifyAddressRouteParams params;
  const _VerifyAddressView({required this.params});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Verify Address on Trezor',
          color: context.appColors.background,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<TrezorVerifyAddressCubit, TrezorOperationState<bool>>(
        listener: (context, state) {
          if (state.isSuccess) {
            SnackBarUtils.showSnackBar(context, 'Address verified on Trezor');
            context.pop();
          } else if (state.isError) {
            SnackBarUtils.showSnackBar(
              context,
              state.errorMessage ?? 'Verification failed',
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
        if (!state.isError) ...[const Gap(24), _buildAddressDisplay(context)],
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
      return Icon(
        Icons.verified_user,
        size: 80,
        color: context.appColors.primary,
      );
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
            onPressed: () => _onVerify(context),
            label: 'Verify Address',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        if (state.isError)
          BBButton.big(
            onPressed: () => context.read<TrezorVerifyAddressCubit>().reset(),
            label: 'Try Again',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
      ],
    );
  }

  Widget _buildAddressDisplay(BuildContext context) {
    final spacedForDisplay = params.address
        .replaceAllMapped(RegExp('.{1,4}'), (m) => '${m.group(0)} ')
        .trim();

    return Column(
      children: [
        BBText(
          'Compare with the address shown on your Trezor device:',
          style: context.font.bodyMedium,
          color: context.appColors.textMuted,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        InkWell(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: params.address));
            SnackBarUtils.showCopiedSnackBar(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.border, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spacedForDisplay,
                  style: context.font.bodyLarge?.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copy,
                      size: 12,
                      color: context.appColors.textMuted,
                    ),
                    const Gap(4),
                    BBText(
                      'Long-press to copy',
                      style: context.font.bodySmall,
                      color: context.appColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Helpers ─────────────────────────

  // TODO: localize all of these once ARB keys are added.

  String _getMainTextForState(TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return 'Confirm on your Trezor device';
    }
    if (state.isProcessing) {
      return 'Verifying…';
    }
    if (state.isError) {
      return 'Verification Failed';
    }
    return 'Verify Receive Address';
  }

  String _getSubTextForState(TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return 'Compare the address shown on your Trezor device with '
          'the one shown here, then confirm on the device.';
    }
    if (state.isProcessing) {
      return 'Returning to your wallet…';
    }
    if (state.isError) {
      return state.errorMessage ?? 'Tap Try Again to retry verification.';
    }
    return 'Tap "Verify Address" to display this address on your '
        'Trezor device and confirm it matches.';
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _onVerify(BuildContext context) async {
    try {
      await context.read<TrezorVerifyAddressCubit>().verify(
        address: params.address,
        derivationPath: params.derivationPath,
        scriptType: params.scriptType,
        isTestnet: params.isTestnet,
      );
    } catch (_) {
      // Cubit already emitted an error state; BlocConsumer listener
      // shows the snackbar. Swallow to prevent uncaught futures.
    }
  }
}
