import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              child: state.isLoading
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
                        LightningAddressActivationFailure.capabilityUnavailable
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
                        LightningAddressActivationFailure.noDefaultBitcoinWallet
                  ? const _NoDefaultBitcoinWalletView()
                  : state.failure ==
                        LightningAddressActivationFailure.submissionUncertain
                  ? _UncertainSubmissionView(
                      onCheckStatus: context
                          .read<LightningAddressActivationCubit>()
                          .load,
                      body: context.loc.lightningAddressUncertainBody,
                      walletBehavior: state.walletBehavior,
                      walletBehaviorSaving: state.walletBehaviorSaving,
                    )
                  : state.failure ==
                        LightningAddressActivationFailure.toggleUncertain
                  ? _UncertainSubmissionView(
                      onCheckStatus: context
                          .read<LightningAddressActivationCubit>()
                          .load,
                      body: context.loc.lightningAddressToggleUncertain,
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
    await context.read<LightningAddressActivationCubit>().submit();
  }

  Future<void> _setOnline({required bool online}) async {
    final cubit = context.read<LightningAddressActivationCubit>();
    if (online) {
      await cubit.activateExisting();
    } else {
      await cubit.deactivate();
    }
  }

  String _failureMessage(
    BuildContext context,
    LightningAddressActivationFailure failure,
  ) {
    return switch (failure) {
      LightningAddressActivationFailure.invalidNym =>
        context.loc.lightningAddressInvalidNym,
      LightningAddressActivationFailure.reservedNym =>
        context.loc.lightningAddressReservedNym,
      LightningAddressActivationFailure.nameTaken =>
        context.loc.lightningAddressNameTaken,
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
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.lightningAddressPermanentFirstClaimTitle,
              style: context.font.titleLarge,
            ),
            const Gap(8),
            Text(
              context.loc.lightningAddressPermanentFirstClaimBody,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const Gap(24),
            if (_nameClaimFailureMessage(context, state.failure)
                case final message?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.error,
                  ),
                ),
              ),
              const Gap(12),
            ],
            TextFormField(
              controller: nymController,
              enabled: !state.isSubmitting,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 32,
              onChanged: onChanged,
              onFieldSubmitted: (_) => state.isSubmitting ? null : onSubmit(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: context.loc.lightningAddressNymLabel,
                helperText: context.loc.lightningAddressPermanentNymHelper,
              ),
              validator: (value) {
                final failure = context
                    .read<LightningAddressActivationCubit>()
                    .validateNym(value ?? '');
                return switch (failure) {
                  LightningAddressActivationFailure.reservedNym =>
                    context.loc.lightningAddressReservedNym,
                  null => null,
                  _ => context.loc.lightningAddressInvalidNym,
                };
              },
            ),
            const Gap(24),
            Semantics(
              liveRegion: state.isSubmitting,
              label: state.isSubmitting
                  ? context.loc.lightningAddressSubmitting
                  : null,
              child: BBButton.big(
                label: state.isSubmitting
                    ? context.loc.lightningAddressSubmitting
                    : context.loc.lightningAddressClaimButton,
                onPressed: onSubmit,
                disabled: state.isSubmitting,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
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

class _UnsupportedView extends StatelessWidget {
  final GetPaidWalletBehavior? walletBehavior;

  const _UnsupportedView({required this.walletBehavior});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusNotice(
          icon: Icons.visibility_off_outlined,
          title: context.loc.lightningAddressPermanentNamesUnavailableTitle,
          body: context.loc.lightningAddressPermanentNamesUnavailableBody,
        ),
        if (walletBehavior != null)
          _WalletBehaviorControls(behavior: walletBehavior!, saving: false),
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
        _StatusNotice(
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
        _StatusNotice(
          icon: Icons.sync_problem_outlined,
          title: context.loc.lightningAddressAlreadyAssignedTitle,
          body: context.loc.lightningAddressAlreadyAssignedBody,
        ),
        if (nym.isNotEmpty) ...[
          const Gap(24),
          _InfoRow(label: context.loc.lightningAddressNymLabel, value: nym),
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
        // Ownership is unknown while lookup is down. Fail closed toward a
        // second permanent-name claim; retry is the only server action.
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
        _StatusNotice(
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
  final String body;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _UncertainSubmissionView({
    required this.onCheckStatus,
    required this.body,
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
          body: body,
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
        _StatusNotice(
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
        _AdvancedSettingsButton(
          online: false,
          onlineSaving: onlineSaving,
          onOnlineChanged: onOnlineChanged,
          walletBehavior: walletBehavior,
          walletBehaviorSaving: walletBehaviorSaving,
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
          _AdvancedSettingsButton(
            online: true,
            onlineSaving: onlineSaving,
            onOnlineChanged: onOnlineChanged,
            walletBehavior: walletBehavior,
            walletBehaviorSaving: walletBehaviorSaving,
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
    final qrData = 'lightning:$address';
    return BorderedTappableTile(
      key: const Key('lightning_address_tile'),
      backgroundColor: context.appColors.surfaceContainerHighest,
      onTap: () => AddressViewer.showDetail(
        context,
        data: address,
        clipboardText: address,
        qrData: qrData,
        showExplorerActions: false,
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
          qrData: qrData,
          showExplorerActions: false,
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

class _AdvancedSettingsButton extends StatelessWidget {
  final bool online;
  final bool onlineSaving;
  final ValueChanged<bool> onOnlineChanged;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _AdvancedSettingsButton({
    required this.online,
    required this.onlineSaving,
    required this.onOnlineChanged,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: () => BlurredBottomSheet.show(
          context: context,
          child: _LightningAddressAdvancedSettingsSheet(
            online: online,
            onlineSaving: onlineSaving,
            onOnlineChanged: onOnlineChanged,
            walletBehavior: walletBehavior,
            walletBehaviorSaving: walletBehaviorSaving,
          ),
        ),
        child: Text(
          context.loc.lightningAddressAdvancedSettings,
          style: TextStyle(color: context.appColors.error),
        ),
      ),
    );
  }
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
        _StatusNotice(
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
        _AdvancedSettingsButton(
          online: true,
          onlineSaving: onlineSaving,
          onOnlineChanged: onOnlineChanged,
          walletBehavior: walletBehavior,
          walletBehaviorSaving: walletBehaviorSaving,
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
      context.loc.lightningAddressInvalidNym,
    LightningAddressActivationFailure.reservedNym =>
      context.loc.lightningAddressReservedNym,
    LightningAddressActivationFailure.nameTaken =>
      context.loc.lightningAddressNameTaken,
    _ => null,
  };
}

class _OnlineControl extends StatelessWidget {
  final bool online;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _OnlineControl({
    required this.online,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('lightning_address_online_switch'),
            value: online,
            onChanged: saving ? null : onChanged,
            title: Text(
              online
                  ? context.loc.lightningAddressOnlineToggleActive
                  : context.loc.lightningAddressOnlineToggleInactive,
            ),
            subtitle: Text(
              online
                  ? context.loc.lightningAddressOnlineToggleActiveBody
                  : context.loc.lightningAddressOnlineToggleInactiveBody,
            ),
          ),
          if (saving)
            Semantics(
              liveRegion: true,
              label: context.loc.lightningAddressOnlineToggleSaving,
              child: const LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _LightningAddressAdvancedSettingsSheet extends StatelessWidget {
  final bool online;
  final bool onlineSaving;
  final ValueChanged<bool> onOnlineChanged;
  final GetPaidWalletBehavior? walletBehavior;
  final bool walletBehaviorSaving;

  const _LightningAddressAdvancedSettingsSheet({
    required this.online,
    required this.onlineSaving,
    required this.onOnlineChanged,
    required this.walletBehavior,
    required this.walletBehaviorSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.lightningAddressAdvancedSettings,
              style: context.font.titleLarge,
            ),
            _OnlineControl(
              online: online,
              saving: onlineSaving,
              onChanged: onOnlineChanged,
            ),
            if (walletBehavior != null)
              _WalletBehaviorControls(
                behavior: walletBehavior!,
                saving: walletBehaviorSaving,
              ),
          ],
        ),
      ),
    );
  }
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
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
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
      ),
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
