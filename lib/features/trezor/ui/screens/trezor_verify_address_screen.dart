import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/trezor/application/usecases/verify_address_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:bb_mobile/features/trezor/ui/trezor_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
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
  final TrezorVerifyAddressRouteParams? params;
  const TrezorVerifyAddressScreen({super.key, this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<TrezorOperationCubit>(),
      child: _VerifyAddressView(params: params),
    );
  }
}

class _VerifyAddressView extends StatelessWidget {
  final TrezorVerifyAddressRouteParams? params;
  const _VerifyAddressView({this.params});

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
      body: BlocConsumer<TrezorOperationCubit, TrezorOperationState>(
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
            onPressed: () => context.read<TrezorOperationCubit>().reset(),
            label: 'Try Again',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
      ],
    );
  }

  Widget _buildAddressDisplay(BuildContext context) {
    final p = params;
    if (p == null) return const SizedBox.shrink();
    return Column(
      children: [
        BBText(
          'Compare with the address shown in Trezor Suite:',
          style: context.font.bodyMedium,
          color: context.appColors.textMuted,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.border, width: 1),
          ),
          child: SelectableText(
            p.address
                .replaceAllMapped(RegExp('.{1,4}'), (m) => '${m.group(0)} ')
                .trim(),
            style: context.font.bodyLarge?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
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
      return 'Trezor Suite will display this address. Compare it with '
          'the one shown here and confirm on your device.';
    }
    if (state.isProcessing) {
      return 'Returning to your wallet…';
    }
    if (state.isError) {
      return 'Tap Try Again to retry verification.';
    }
    return 'Tap "Verify Address" to display this address in Trezor '
        'Suite and confirm it matches.';
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _onVerify(BuildContext context) async {
    final cubit = context.read<TrezorOperationCubit>();
    try {
      await cubit.executeOperation(() async {
        final p = params;
        if (p == null) {
          throw Exception('Missing address parameters');
        }
        return await locator<VerifyAddressTrezorUsecase>().execute(
          address: p.address,
          derivationPath: p.derivationPath,
          scriptType: p.scriptType,
        );
      });
    } catch (_) {
      // Cubit already emitted an error state; BlocConsumer listener
      // shows the snackbar. Swallow to prevent uncaught futures.
    }
  }
}
