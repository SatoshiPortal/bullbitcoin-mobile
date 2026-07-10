import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class LightningAddressActivationScreen extends StatefulWidget {
  const LightningAddressActivationScreen({super.key});

  @override
  State<LightningAddressActivationScreen> createState() =>
      _LightningAddressActivationScreenState();
}

class _LightningAddressActivationScreenState
    extends State<LightningAddressActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nymController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LightningAddressActivationCubit>().load();
  }

  @override
  void dispose() {
    _nymController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      LightningAddressActivationCubit,
      LightningAddressActivationState
    >(
      listenWhen: (previous, current) => previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure == null) return;
        SnackBarUtils.showSnackBar(context, _failureMessage(context, failure));
      },
      builder: (context, state) {
        if (_nymController.text != state.nym) {
          _nymController.text = state.nym;
        }

        return PopScope(
          canPop: !state.isSubmitting,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !state.isSubmitting) return;
            SnackBarUtils.showSnackBar(
              context,
              context.loc.lightningAddressOperationInProgress,
            );
          },
          child: Scaffold(
            appBar: AppBar(title: Text(context.loc.lightningAddressTitle)),
            body: SafeArea(
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LoadingBoxContent(height: 72),
                          LoadingLineContent(),
                          LoadingLineContent(width: 220),
                        ],
                      ),
                    )
                  : state.isRegistered
                  ? _RegisteredView(
                      nym: state.nym,
                      lightningAddress: state.registeredAddress!,
                      receiveReady: state.receiveReady,
                      autoSweepConfirmed: state.autoSweepConfirmed,
                      walletBehavior: state.walletBehavior,
                      walletBehaviorSaving: state.walletBehaviorSaving,
                    )
                  : state.isActive
                  ? _ActiveView(
                      nym: state.nym,
                      lightningAddress: state.registeredAddress,
                      receiveReady: state.receiveReady,
                      autoSweepConfirmed: state.autoSweepConfirmed,
                      walletBehavior: state.walletBehavior,
                      walletBehaviorSaving: state.walletBehaviorSaving,
                    )
                  : state.isActiveLocalSetupFailed
                  ? _ActiveLocalSetupFailedView(
                      nym: state.nym,
                      lightningAddress: state.registeredAddress,
                      localSetupRetryable: state.localSetupRetryable,
                      onCheckStatus: context
                          .read<LightningAddressActivationCubit>()
                          .load,
                      walletBehavior: state.walletBehavior,
                      walletBehaviorSaving: state.walletBehaviorSaving,
                    )
                  : state.isInactive
                  ? _InactiveKnownView(
                      nym: state.nym,
                      onCheckStatus: context
                          .read<LightningAddressActivationCubit>()
                          .load,
                      onRegister: context
                          .read<LightningAddressActivationCubit>()
                          .showRegistrationForm,
                    )
                  : state.failure ==
                        LightningAddressActivationFailure.lookupFailed
                  ? _LookupFailureView(
                      onCheckStatus: context
                          .read<LightningAddressActivationCubit>()
                          .load,
                      onRegister: context
                          .read<LightningAddressActivationCubit>()
                          .showRegistrationForm,
                      walletBehavior: state.walletBehavior,
                      walletBehaviorSaving: state.walletBehaviorSaving,
                    )
                  : state.failure ==
                        LightningAddressActivationFailure.noDefaultBitcoinWallet
                  ? const _NoDefaultBitcoinWalletView()
                  : state.failure ==
                        LightningAddressActivationFailure.submissionUncertain
                  ? _UncertainSubmissionView(
                      onCheckStatus: context
                          .read<LightningAddressActivationCubit>()
                          .load,
                      walletBehavior: state.walletBehavior,
                      walletBehaviorSaving: state.walletBehaviorSaving,
                    )
                  : _RegistrationForm(
                      formKey: _formKey,
                      nymController: _nymController,
                      state: state,
                      onChanged: context
                          .read<LightningAddressActivationCubit>()
                          .nymChanged,
                      onSubmit: _submit,
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.loc.lightningAddressConfirmTitle),
          content: Text(dialogContext.loc.lightningAddressConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.loc.lightningAddressConfirmCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.loc.lightningAddressConfirmSubmit),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    await context.read<LightningAddressActivationCubit>().submit();
  }

  String _failureMessage(
    BuildContext context,
    LightningAddressActivationFailure failure,
  ) {
    return switch (failure) {
      LightningAddressActivationFailure.invalidNym =>
        context.loc.lightningAddressInvalidNym,
      LightningAddressActivationFailure.lookupFailed =>
        context.loc.lightningAddressLookupFailedBody,
      LightningAddressActivationFailure.noDefaultBitcoinWallet =>
        context.loc.lightningAddressNoDefaultBitcoinWalletError,
      LightningAddressActivationFailure.setupFailed =>
        context.loc.lightningAddressSetupFailed,
      LightningAddressActivationFailure.submissionUncertain =>
        context.loc.lightningAddressUncertainBody,
      LightningAddressActivationFailure.rejected =>
        context.loc.lightningAddressRejected,
      LightningAddressActivationFailure.serverTemporary =>
        context.loc.lightningAddressServerTemporary,
      LightningAddressActivationFailure.network =>
        context.loc.lightningAddressNetworkError,
      LightningAddressActivationFailure.generic =>
        context.loc.lightningAddressGenericError,
    };
  }
}

class _RegistrationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nymController;
  final LightningAddressActivationState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const _RegistrationForm({
    required this.formKey,
    required this.nymController,
    required this.state,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.lightningAddressInactiveTitle,
              style: context.font.titleLarge,
            ),
            const Gap(8),
            Text(
              context.loc.lightningAddressInactiveBody,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const Gap(24),
            TextFormField(
              controller: nymController,
              enabled: !state.isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: onChanged,
              onFieldSubmitted: (_) => state.isSubmitting ? null : onSubmit(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: context.loc.lightningAddressNymLabel,
                helperText: context.loc.lightningAddressNymHelper,
              ),
              validator: (value) {
                final failure = context
                    .read<LightningAddressActivationCubit>()
                    .validateNym(value ?? '');
                if (failure != null) {
                  return context.loc.lightningAddressInvalidNym;
                }
                return null;
              },
            ),
            const Gap(24),
            BBButton.big(
              label: state.isSubmitting
                  ? context.loc.lightningAddressSubmitting
                  : context.loc.lightningAddressRegisterButton,
              onPressed: onSubmit,
              disabled: state.isSubmitting,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDefaultBitcoinWalletView extends StatelessWidget {
  const _NoDefaultBitcoinWalletView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.account_balance_wallet_outlined,
          title: context.loc.lightningAddressTitle,
          body: context.loc.lightningAddressNoDefaultBitcoinWalletError,
        ),
      ],
    );
  }
}

class _LookupFailureView extends StatelessWidget {
  final VoidCallback onCheckStatus;
  final VoidCallback onRegister;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _LookupFailureView({
    required this.onCheckStatus,
    required this.onRegister,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.error_outline,
          title: context.loc.lightningAddressLookupFailedTitle,
          body: context.loc.lightningAddressLookupFailedBody,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.lightningAddressCheckStatusButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onCheckStatus,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(12),
        // Registration is independent of the status lookup, so a first-time
        // user whose lookup failed must still be able to start registration
        // instead of being stuck on retry-only (I10).
        BBButton.big(
          label: context.loc.lightningAddressRegisterButton,
          onPressed: onRegister,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        // The behavior controls only need the local wallet, so they stay
        // reachable even while the server status lookup is failing.
        if (walletBehavior != null)
          _WalletBehaviorControls(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
          ),
      ],
    );
  }
}

class _UncertainSubmissionView extends StatelessWidget {
  final VoidCallback onCheckStatus;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _UncertainSubmissionView({
    required this.onCheckStatus,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.help_outline,
          title: context.loc.lightningAddressUncertainTitle,
          body: context.loc.lightningAddressUncertainBody,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.lightningAddressCheckStatusButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onCheckStatus,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        if (walletBehavior != null)
          _WalletBehaviorControls(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
          ),
      ],
    );
  }
}

class _InactiveKnownView extends StatelessWidget {
  final String nym;
  final VoidCallback onCheckStatus;
  final VoidCallback onRegister;

  const _InactiveKnownView({
    required this.nym,
    required this.onCheckStatus,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.info_outline,
          title: context.loc.lightningAddressInactiveKnownTitle,
          body: context.loc.lightningAddressInactiveKnownBody,
        ),
        const Gap(24),
        _InfoRow(label: context.loc.lightningAddressNymLabel, value: nym),
        const Gap(24),
        BBButton.big(
          label: context.loc.lightningAddressCheckStatusButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onCheckStatus,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(12),
        BBButton.big(
          label: context.loc.lightningAddressRegisterButton,
          onPressed: onRegister,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }
}

class _ActiveView extends StatelessWidget {
  final String nym;
  final String? lightningAddress;
  final bool receiveReady;
  final bool autoSweepConfirmed;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _ActiveView({
    required this.nym,
    required this.lightningAddress,
    required this.receiveReady,
    required this.autoSweepConfirmed,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.check_circle,
          title: context.loc.lightningAddressActiveTitle,
          body: lightningAddress == null
              ? context.loc.lightningAddressNoCopyableAddressAfterLookup
              : context.loc.lightningAddressCopyableAddressAfterLookup,
        ),
        const Gap(24),
        _InfoRow(label: context.loc.lightningAddressNymLabel, value: nym),
        if (lightningAddress != null) ...[
          const Gap(16),
          CopyInput(
            text: lightningAddress!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const Gap(16),
        _InfoRow(
          label: context.loc.lightningAddressReceiveReadinessLabel,
          value: _receiveReadinessCopy(
            context,
            receiveReady: receiveReady,
            autoSweepConfirmed: autoSweepConfirmed,
          ),
        ),
        if (walletBehavior != null)
          _WalletBehaviorControls(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
          ),
      ],
    );
  }
}

class _ActiveLocalSetupFailedView extends StatelessWidget {
  final String nym;
  final String? lightningAddress;
  final bool localSetupRetryable;
  final VoidCallback onCheckStatus;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _ActiveLocalSetupFailedView({
    required this.nym,
    required this.lightningAddress,
    required this.localSetupRetryable,
    required this.onCheckStatus,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.warning_amber_outlined,
          title: context.loc.lightningAddressLocalSetupFailedTitle,
          body: localSetupRetryable
              ? context.loc.lightningAddressLocalSetupFailedBody
              : context.loc.lightningAddressLocalSetupNotRetryableBody,
        ),
        const Gap(24),
        _InfoRow(label: context.loc.lightningAddressNymLabel, value: nym),
        if (lightningAddress != null) ...[
          const Gap(16),
          CopyInput(
            text: lightningAddress!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (localSetupRetryable) ...[
          const Gap(24),
          BBButton.big(
            label: context.loc.lightningAddressRetrySetupButton,
            iconData: Icons.refresh,
            iconFirst: true,
            onPressed: onCheckStatus,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
        if (walletBehavior != null)
          _WalletBehaviorControls(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
          ),
      ],
    );
  }
}

class _RegisteredView extends StatelessWidget {
  final String nym;
  final String lightningAddress;
  final bool receiveReady;
  final bool autoSweepConfirmed;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _RegisteredView({
    required this.nym,
    required this.lightningAddress,
    required this.receiveReady,
    required this.autoSweepConfirmed,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.check_circle,
          title: context.loc.lightningAddressSuccessTitle,
          body: context.loc.lightningAddressSuccessBody,
        ),
        const Gap(24),
        _InfoRow(label: context.loc.lightningAddressNymLabel, value: nym),
        const Gap(16),
        CopyInput(
          text: lightningAddress,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(16),
        _InfoRow(
          label: context.loc.lightningAddressReceiveReadinessLabel,
          value: _receiveReadinessCopy(
            context,
            receiveReady: receiveReady,
            autoSweepConfirmed: autoSweepConfirmed,
          ),
        ),
        if (walletBehavior != null)
          _WalletBehaviorControls(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
          ),
      ],
    );
  }
}

// R2-D1b: only claim autosweep is enabled when the wallet's actual behavior
// metadata has confirmed it; otherwise soften to a plain ready state so the UI
// never over-reassures a user whose funds could stay put.
String _receiveReadinessCopy(
  BuildContext context, {
  required bool receiveReady,
  required bool autoSweepConfirmed,
}) {
  if (!receiveReady) {
    return context.loc.lightningAddressReceiveNotReady;
  }
  return autoSweepConfirmed
      ? context.loc.lightningAddressReceiveReady
      : context.loc.lightningAddressReceiveReadyNoAutosweep;
}

/// Reserved-wallet behavior controls (auto-sweep + hide-on-home) for wallet 101.
/// Mirrors BTCPay's `_BtcpayWalletBehaviorTile`; the safe defaults are applied
/// at wallet creation, these rows only let the user review and change them.
class _WalletBehaviorControls extends StatelessWidget {
  final GetPaidWalletBehavior behavior;
  final bool saving;

  const _WalletBehaviorControls({required this.behavior, required this.saving});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LightningAddressActivationCubit>();
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          ListTile(title: Text(context.loc.getPaidWalletSettingsSectionTitle)),
          SwitchListTile(
            value: behavior.autoSweepEnabled,
            onChanged: saving
                ? null
                : (value) => cubit.updateWalletBehavior(
                    walletId: behavior.walletId,
                    autoSweepEnabled: value,
                  ),
            title: Text(context.loc.getPaidWalletAutoSweepLabel),
            subtitle: Text(context.loc.getPaidWalletAutoSweepInfo),
          ),
          SwitchListTile(
            value: behavior.hideOnHome,
            onChanged: saving
                ? null
                : (value) => cubit.updateWalletBehavior(
                    walletId: behavior.walletId,
                    hideOnHome: value,
                  ),
            title: Text(context.loc.getPaidWalletHideOnHomeLabel),
            subtitle: Text(context.loc.getPaidWalletHideOnHomeInfo),
          ),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _StatusNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appColors.primary, size: 48),
        const Gap(16),
        Text(title, style: context.font.titleLarge),
        const Gap(8),
        Text(
          body,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        Text(value, style: context.font.bodyLarge),
      ],
    );
  }
}
