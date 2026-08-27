import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          _nymController.value = TextEditingValue(
            text: state.nym,
            selection: TextSelection.collapsed(offset: state.nym.length),
          );
        }

        return PopScope(
          canPop: !state.isBusy,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !state.isBusy) return;
            SnackBarUtils.showSnackBar(
              context,
              context.loc.lightningAddressOperationInProgress,
            );
          },
          child: Scaffold(
            appBar: AppBar(title: Text(context.loc.lightningAddressTitle)),
            body: SafeArea(
              child: _withWalletBehaviorWarning(
                state,
                state.isLoading
                    ? Semantics(
                        liveRegion: true,
                        label: context.loc.lightningAddressLoadingStatus,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LoadingBoxContent(height: 72),
                              LoadingLineContent(),
                              LoadingLineContent(width: 220),
                            ],
                          ),
                        ),
                      )
                    : state.isUnsupported
                    ? _UnsupportedView(walletBehavior: state.walletBehavior)
                    : state.isAddressUnavailable
                    ? _AddressUnavailableView(
                        onReload: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                      )
                    : state.isActive
                    ? _ActiveView(
                        lightningAddress: state.registeredAddress,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                        canManage:
                            state.permanentNamesSupported &&
                            state.hasPermanentNym,
                        onlineSaving: state.onlineSaving,
                        onOnlineChanged: (online) => _setOnline(online: online),
                        onReload: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                      )
                    : state.isActiveLocalSetupFailed
                    ? _ActiveLocalSetupFailedView(
                        lightningAddress: state.registeredAddress,
                        localSetupRetryable: state.localSetupRetryable,
                        onCheckStatus: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                        onlineSaving: state.onlineSaving,
                        onOnlineChanged: (online) => _setOnline(online: online),
                      )
                    : state.isInactive
                    ? _InactiveKnownView(
                        lightningAddress: state.registeredAddress,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                        onlineSaving: state.onlineSaving,
                        onOnlineChanged: (online) => _setOnline(online: online),
                        onReload: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                      )
                    : state.failure ==
                          LightningAddressActivationFailure
                              .capabilityUnavailable
                    ? _CapabilityUnavailableView(
                        onCheckStatus: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                      )
                    : state.failure ==
                          LightningAddressActivationFailure.alreadyAssigned
                    ? _OwnershipConflictView(
                        nym: state.nym,
                        onCheckStatus: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                      )
                    : state.failure ==
                          LightningAddressActivationFailure.lookupFailed
                    ? _LookupFailureView(
                        onCheckStatus: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                      )
                    : state.failure ==
                          LightningAddressActivationFailure
                              .noDefaultBitcoinWallet
                    ? const _NoDefaultBitcoinWalletView()
                    : state.failure ==
                          LightningAddressActivationFailure.noServerResponse
                    ? _ServerOutcomeView(
                        title:
                            context.loc.lightningAddressNoServerResponseTitle,
                        body: context.loc.lightningAddressNoServerResponseBody,
                        actionLabel:
                            context.loc.lightningAddressClaimRetryButton,
                        // Straight to the cubit: it re-validates the nym it
                        // still holds, and no form is mounted on this view.
                        onAction: context
                            .read<LightningAddressActivationCubit>()
                            .submit,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                      )
                    : state.failure ==
                          LightningAddressActivationFailure.submissionUncertain
                    ? _ServerOutcomeView(
                        title: context.loc.lightningAddressUncertainTitle,
                        body: context.loc.lightningAddressUncertainBody,
                        actionLabel:
                            context.loc.lightningAddressCheckStatusButton,
                        onAction: context
                            .read<LightningAddressActivationCubit>()
                            .load,
                        walletBehavior: state.walletBehavior,
                        walletBehaviorSaving: state.walletBehaviorSaving,
                      )
                    : state.failure ==
                          LightningAddressActivationFailure.toggleUncertain
                    ? _ServerOutcomeView(
                        title: context.loc.lightningAddressUncertainTitle,
                        body: context.loc.lightningAddressToggleUncertain,
                        actionLabel:
                            context.loc.lightningAddressCheckStatusButton,
                        onAction: context
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
          ),
        );
      },
    );
  }

  Widget _withWalletBehaviorWarning(
    LightningAddressActivationState state,
    Widget body,
  ) {
    if (!state.walletBehaviorUnavailable) return body;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GetPaidWalletBehaviorUnavailableWarning(
            onRetry: context
                .read<LightningAddressActivationCubit>()
                .retryWalletBehavior,
            isRetrying: state.walletBehaviorSaving,
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<LightningAddressActivationCubit>().submit();
  }

  Future<void> _setOnline({required bool online}) async {
    final cubit = context.read<LightningAddressActivationCubit>();
    if (online) {
      await cubit.activateExisting();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.lightningAddressTurnOffConfirmTitle),
        content: Text(dialogContext.loc.lightningAddressTurnOffConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.loc.lightningAddressTurnOffConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.loc.lightningAddressTurnOffConfirmSubmit),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    // The cubit re-checks the live status, so a deactivation that raced with
    // this dialog is dropped there rather than re-issued here.
    await cubit.deactivate();
  }

  String _failureMessage(
    BuildContext context,
    LightningAddressActivationFailure failure,
  ) {
    return switch (failure) {
      LightningAddressActivationFailure.invalidNym =>
        context.loc.getPaidNymInvalid,
      LightningAddressActivationFailure.reservedNym =>
        context.loc.getPaidNymReserved,
      LightningAddressActivationFailure.nameTaken =>
        context.loc.getPaidNymTaken,
      LightningAddressActivationFailure.alreadyAssigned =>
        context.loc.lightningAddressAlreadyAssigned,
      LightningAddressActivationFailure.capabilityUnavailable =>
        context.loc.lightningAddressCapabilityUnavailableBody,
      LightningAddressActivationFailure.lookupFailed =>
        context.loc.lightningAddressLookupFailedBody,
      LightningAddressActivationFailure.noDefaultBitcoinWallet =>
        context.loc.lightningAddressNoDefaultBitcoinWalletError,
      LightningAddressActivationFailure.setupFailed =>
        context.loc.lightningAddressSetupFailed,
      LightningAddressActivationFailure.noServerResponse =>
        context.loc.lightningAddressNoServerResponseBody,
      LightningAddressActivationFailure.submissionUncertain =>
        context.loc.lightningAddressUncertainBody,
      LightningAddressActivationFailure.rejected =>
        context.loc.lightningAddressRejected,
      LightningAddressActivationFailure.serverTemporary =>
        context.loc.lightningAddressServerTemporary,
      LightningAddressActivationFailure.network =>
        context.loc.lightningAddressNetworkError,
      LightningAddressActivationFailure.toggleUncertain =>
        context.loc.lightningAddressToggleUncertain,
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
      child: GetPaidNymClaimStep(
        formKey: formKey,
        controller: nymController,
        submitting: state.isSubmitting,
        errorText: _nameClaimFailureMessage(context, state.failure),
        onChanged: onChanged,
        onSubmit: onSubmit,
        validator: (value) {
          final failure = context
              .read<LightningAddressActivationCubit>()
              .validateNym(value ?? '');
          return switch (failure) {
            LightningAddressActivationFailure.reservedNym =>
              context.loc.getPaidNymReserved,
            null => null,
            _ => context.loc.getPaidNymInvalid,
          };
        },
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
        GetPaidStatusNotice(
          icon: Icons.account_balance_wallet_outlined,
          title: context.loc.lightningAddressTitle,
          body: context.loc.lightningAddressNoDefaultBitcoinWalletError,
        ),
      ],
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  final GetPaidWalletBehavior? walletBehavior;

  const _UnsupportedView({required this.walletBehavior});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
          icon: Icons.visibility_off_outlined,
          title: context.loc.lightningAddressPermanentNamesUnavailableTitle,
          body: context.loc.lightningAddressPermanentNamesUnavailableBody,
        ),
        if (walletBehavior != null)
          GetPaidWalletBehaviorCard(
            behavior: walletBehavior!,
            saving: false,
            onAutoSweepChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  autoSweepEnabled: value,
                ),
            onHideOnHomeChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  hideOnHome: value,
                ),
          ),
      ],
    );
  }
}

class _CapabilityUnavailableView extends StatelessWidget {
  final VoidCallback onCheckStatus;

  const _CapabilityUnavailableView({required this.onCheckStatus});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
          icon: Icons.cloud_off_outlined,
          title: context.loc.lightningAddressCapabilityUnavailableTitle,
          body: context.loc.lightningAddressCapabilityUnavailableBody,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.lightningAddressRetryAddressButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onCheckStatus,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}

class _OwnershipConflictView extends StatelessWidget {
  final String nym;
  final VoidCallback onCheckStatus;

  const _OwnershipConflictView({
    required this.nym,
    required this.onCheckStatus,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
          icon: Icons.sync_problem_outlined,
          title: context.loc.lightningAddressAlreadyAssignedTitle,
          body: context.loc.lightningAddressAlreadyAssignedBody,
        ),
        if (nym.isNotEmpty) ...[
          const Gap(24),
          GetPaidInfoRow(label: context.loc.getPaidNymLabel, value: nym),
        ],
        const Gap(24),
        BBButton.big(
          label: context.loc.lightningAddressCheckStatusButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onCheckStatus,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}

class _LookupFailureView extends StatelessWidget {
  final VoidCallback onCheckStatus;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _LookupFailureView({
    required this.onCheckStatus,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
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
        // Ownership is unknown while lookup is down. Fail closed toward a
        // second permanent-name claim; retry is the only server action.
        // The behavior controls only need the local wallet, so they stay
        // reachable even while the server status lookup is failing.
        if (walletBehavior != null)
          GetPaidWalletBehaviorCard(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
            onAutoSweepChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  autoSweepEnabled: value,
                ),
            onHideOnHomeChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  hideOnHome: value,
                ),
          ),
      ],
    );
  }
}

class _AddressUnavailableView extends StatelessWidget {
  final VoidCallback onReload;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _AddressUnavailableView({
    required this.onReload,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
          icon: Icons.error_outline,
          title: context.loc.lightningAddressTitle,
          body: context.loc.lightningAddressAddressUnavailableBody,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.lightningAddressRetryAddressButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onReload,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        if (walletBehavior != null)
          GetPaidWalletBehaviorCard(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
            onAutoSweepChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  autoSweepEnabled: value,
                ),
            onHideOnHomeChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  hideOnHome: value,
                ),
          ),
      ],
    );
  }
}

/// An outcome the server left the app to explain: either nothing came back at
/// all, or something came back that leaves the claim half-known. Each caller
/// supplies its own wording and its own single next action — retry the claim, or
/// re-read the status — so neither case borrows the other's story.
class _ServerOutcomeView extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _ServerOutcomeView({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(icon: Icons.help_outline, title: title, body: body),
        const Gap(24),
        BBButton.big(
          key: const Key('lightning_address_server_outcome_action'),
          label: actionLabel,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onAction,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        if (walletBehavior != null)
          GetPaidWalletBehaviorCard(
            behavior: walletBehavior!,
            saving: walletBehaviorSaving,
            onAutoSweepChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  autoSweepEnabled: value,
                ),
            onHideOnHomeChanged: (value) => context
                .read<LightningAddressActivationCubit>()
                .updateWalletBehavior(
                  walletId: walletBehavior!.walletId,
                  hideOnHome: value,
                ),
          ),
      ],
    );
  }
}

class _InactiveKnownView extends StatelessWidget {
  final String? lightningAddress;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;
  final bool onlineSaving;
  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback onReload;

  const _InactiveKnownView({
    required this.lightningAddress,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
    required this.onlineSaving,
    required this.onOnlineChanged,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
          icon: Icons.info_outline,
          title: context.loc.lightningAddressInactiveKnownTitle,
          body: context.loc.lightningAddressOnlineToggleInactiveBody,
        ),
        if (lightningAddress case final address?) ...[
          const Gap(24),
          _LightningAddressTile(address: address),
        ] else ...[
          const Gap(24),
          _MissingAddressView(onReload: onReload),
        ],
        const Gap(24),
        _advancedSettingsButton(
          context,
          online: false,
          onlineSaving: onlineSaving,
          onOnlineChanged: onOnlineChanged,
        ),
      ],
    );
  }
}

class _ActiveView extends StatelessWidget {
  final String? lightningAddress;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;
  final bool canManage;
  final bool onlineSaving;
  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback onReload;

  const _ActiveView({
    required this.lightningAddress,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
    required this.canManage,
    required this.onlineSaving,
    required this.onOnlineChanged,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: context.appColors.success,
                size: 72,
              ),
              const Gap(16),
              Text(
                context.loc.lightningAddressActiveTitle,
                style: context.font.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (lightningAddress != null) ...[
          const Gap(32),
          _LightningAddressTile(address: lightningAddress!),
        ],
        if (lightningAddress == null) ...[
          const Gap(32),
          _MissingAddressView(onReload: onReload),
        ],
        if (canManage) ...[
          const Gap(32),
          _advancedSettingsButton(
            context,
            online: true,
            onlineSaving: onlineSaving,
            onOnlineChanged: onOnlineChanged,
          ),
        ],
      ],
    );
  }
}

class _LightningAddressTile extends StatelessWidget {
  final String address;

  const _LightningAddressTile({required this.address});

  @override
  Widget build(BuildContext context) {
    return BorderedTappableTile(
      key: const Key('lightning_address_tile'),
      backgroundColor: context.appColors.surfaceContainerHighest,
      onTap: () => AddressViewer.showDetail(
        context,
        data: address,
        clipboardText: address,
      ),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: address));
        SnackBarUtils.showCopiedSnackBar(context);
      },
      child: IgnorePointer(
        child: AddressViewer(
          address,
          style: context.font.bodyLarge,
          color: context.appColors.secondary,
          clipboardText: address,
        ),
      ),
    );
  }
}

class _MissingAddressView extends StatelessWidget {
  final VoidCallback onReload;

  const _MissingAddressView({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.lightningAddressAddressUnavailableBody,
          textAlign: TextAlign.center,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(16),
        BBButton.big(
          label: context.loc.lightningAddressRetryAddressButton,
          iconData: Icons.refresh,
          iconFirst: true,
          onPressed: onReload,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}

Widget _advancedSettingsButton(
  BuildContext context, {
  required bool online,
  required bool onlineSaving,
  required ValueChanged<bool> onOnlineChanged,
}) {
  // The sheet lives in a modal route whose context has no provider, so the
  // cubit is carried into it explicitly and its contents are rebuilt from
  // state: a wallet-behavior write made from inside the sheet has to be
  // visible in the sheet that made it.
  final cubit = context.read<LightningAddressActivationCubit>();
  return GetPaidAdvancedSettingsButton(
    label: context.loc.lightningAddressAdvancedSettings,
    sheetBuilder: (_) => BlocProvider<LightningAddressActivationCubit>.value(
      value: cubit,
      child:
          BlocBuilder<
            LightningAddressActivationCubit,
            LightningAddressActivationState
          >(
            builder: (context, state) {
              final behavior = state.walletBehavior;
              return _LightningAddressAdvancedSettingsSheet(
                online: online,
                onlineSaving: onlineSaving,
                onOnlineChanged: onOnlineChanged,
                walletBehavior: behavior,
                walletBehaviorSaving: state.walletBehaviorSaving,
                onAutoSweepChanged: (value) => cubit.updateWalletBehavior(
                  walletId: behavior!.walletId,
                  autoSweepEnabled: value,
                ),
                onHideOnHomeChanged: (value) => cubit.updateWalletBehavior(
                  walletId: behavior!.walletId,
                  hideOnHome: value,
                ),
              );
            },
          ),
    ),
  );
}

class _ActiveLocalSetupFailedView extends StatelessWidget {
  final String? lightningAddress;
  final bool localSetupRetryable;
  final VoidCallback onCheckStatus;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;
  final bool onlineSaving;
  final ValueChanged<bool> onOnlineChanged;

  const _ActiveLocalSetupFailedView({
    required this.lightningAddress,
    required this.localSetupRetryable,
    required this.onCheckStatus,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
    required this.onlineSaving,
    required this.onOnlineChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GetPaidStatusNotice(
          icon: Icons.warning_amber_outlined,
          title: context.loc.lightningAddressLocalSetupFailedTitle,
          body: localSetupRetryable
              ? context.loc.lightningAddressLocalSetupFailedBody
              : context.loc.lightningAddressLocalSetupNotRetryableBody,
        ),
        if (lightningAddress != null) ...[
          const Gap(24),
          _LightningAddressTile(address: lightningAddress!),
        ] else ...[
          const Gap(24),
          _MissingAddressView(onReload: onCheckStatus),
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
        const Gap(24),
        _advancedSettingsButton(
          context,
          online: true,
          onlineSaving: onlineSaving,
          onOnlineChanged: onOnlineChanged,
        ),
      ],
    );
  }
}

String? _nameClaimFailureMessage(
  BuildContext context,
  LightningAddressActivationFailure? failure,
) {
  return switch (failure) {
    LightningAddressActivationFailure.invalidNym =>
      context.loc.getPaidNymInvalid,
    LightningAddressActivationFailure.reservedNym =>
      context.loc.getPaidNymReserved,
    LightningAddressActivationFailure.nameTaken => context.loc.getPaidNymTaken,
    _ => null,
  };
}

class _LightningAddressAdvancedSettingsSheet extends StatelessWidget {
  final bool online;
  final bool onlineSaving;
  final ValueChanged<bool> onOnlineChanged;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;
  final ValueChanged<bool> onAutoSweepChanged;
  final ValueChanged<bool> onHideOnHomeChanged;

  const _LightningAddressAdvancedSettingsSheet({
    required this.online,
    required this.onlineSaving,
    required this.onOnlineChanged,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
    required this.onAutoSweepChanged,
    required this.onHideOnHomeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Presentational only: the cubit lives outside this modal's context, so the
    // behavior callbacks are supplied by the caller (which has the provider).
    return GetPaidAdvancedSettingsSheet(
      onlineSwitchKey: const Key('lightning_address_online_switch'),
      onlineTitle: online
          ? context.loc.lightningAddressOnlineToggleActive
          : context.loc.lightningAddressOnlineToggleInactive,
      onlineSubtitle: online
          ? context.loc.lightningAddressOnlineToggleActiveBody
          : context.loc.lightningAddressOnlineToggleInactiveBody,
      online: online,
      onlineSaving: onlineSaving,
      onlineSavingLabel: context.loc.lightningAddressOnlineToggleSaving,
      onOnlineChanged: onOnlineChanged,
      walletBehavior: walletBehavior,
      walletBehaviorSaving: walletBehaviorSaving,
      onAutoSweepChanged: onAutoSweepChanged,
      onHideOnHomeChanged: onHideOnHomeChanged,
    );
  }
}
