import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_state.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInputText, BullPasteInput, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_privacy/screen_privacy.dart';

class BullVaultRestoreScreen extends StatefulWidget {
  final void Function(BullVaultRestoreResult)? onRecovered;
  final ValueChanged<bool>? onRestoringChanged;

  const BullVaultRestoreScreen({
    super.key,
    this.onRecovered,
    this.onRestoringChanged,
  });

  @override
  State<BullVaultRestoreScreen> createState() => _BullVaultRestoreScreenState();
}

class _BullVaultRestoreScreenState extends State<BullVaultRestoreScreen>
    with PrivacyScreen {
  var _label = '';
  var _mobilePassphrase = '';
  var _descriptor = '';
  ({BullVaultRestoreInputKind kind, String source})? _restoredSource;

  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_label.isEmpty) {
      _label = context.loc.bullVaultWalletLabel;
    }
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRestoring = context.select(
      (BullVaultRestoreCubit cubit) => cubit.state.isRestoring,
    );
    return PopScope(
      canPop: !isRestoring,
      child: BlocConsumer<BullVaultRestoreCubit, BullVaultRestoreState>(
        listenWhen: (previous, current) =>
            previous.isRestoring != current.isRestoring ||
            previous.failure != current.failure ||
            previous.result != current.result,
        listener: (context, state) {
          widget.onRestoringChanged?.call(state.isRestoring);
          if (state.failure case final failure?) {
            SnackBarUtils.showSnackBar(
              context,
              state.result == null
                  ? failure.toTranslated(context)
                  : context.loc.bullVaultRestoreMobilePassphraseFailure,
            );
          } else if (!state.isRestoring && state.result != null) {
            widget.onRecovered?.call(state.result!);
          }
        },
        builder: (context, state) => state.result != null
            ? _restored(context, state.result!, state.isRestoring)
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text(
                    context.loc.bullVaultRestoreDescription,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(24),
                  Text(
                    context.loc.labelInputLabel,
                    style: context.font.bodyMedium,
                  ),
                  const Gap(8),
                  BullInputText(
                    value: _label,
                    onChanged: (value) => setState(() => _label = value),
                    disabled: state.isRestoring,
                    maxLines: 1,
                  ),
                  const Gap(28),
                  Text(
                    context.loc.bullVaultRestorePackageTitle,
                    style: context.font.titleMedium,
                  ),
                  const Gap(8),
                  Text(
                    context.loc.bullVaultRestorePackageDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(16),
                  BullButton.big(
                    label: context.loc.bullVaultChooseRecoveryPackage,
                    onPressed: _pickPackage,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    iconData: Icons.file_open_outlined,
                    iconFirst: true,
                    disabled: state.isRestoring,
                  ),
                  const Gap(28),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          context.loc.bullVaultOr,
                          style: context.font.bodySmall?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const Gap(28),
                  Text(
                    context.loc.bullVaultCompatibleDescriptorTitle,
                    style: context.font.titleMedium,
                  ),
                  const Gap(8),
                  Text(
                    context.loc.bullVaultRestoreDescriptorDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(16),
                  BullPasteInput(
                    text: _descriptor,
                    hint: context.loc.bullVaultDescriptorHint,
                    onChanged: (value) => setState(() => _descriptor = value),
                    onScan: _scanDescriptor,
                    onPasteError: (_) => SnackBarUtils.showSnackBar(
                      context,
                      context.loc.bullVaultFailureInvalidRecovery,
                    ),
                    enabled: !state.isRestoring,
                    minLines: 4,
                    maxLines: 8,
                  ),
                  const Gap(12),
                  BullButton.big(
                    label: context.loc.bullVaultRestoreDescriptorAction,
                    onPressed: _restoreDescriptor,
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                    disabled: state.isRestoring,
                  ),
                  if (state.isRestoring) ...[
                    const Gap(24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _restored(
    BuildContext context,
    BullVaultRestoreResult result,
    bool isRestoring,
  ) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        context.loc.bullVaultRestoreCompleteTitle,
        style: context.font.titleLarge,
      ),
      const Gap(16),
      Text(switch (result.mobileAccess) {
        BullVaultMobileAccess.available =>
          context.loc.bullVaultRestoreMobileAvailable,
        BullVaultMobileAccess.recoveryOnly =>
          context.loc.bullVaultRestoreRecoveryOnly,
        BullVaultMobileAccess.unavailable =>
          context.loc.bullVaultRestoreWatchOnly,
      }, style: context.font.bodyLarge),
      const Gap(16),
      Text(
        context.loc.bullVaultRestoreHardwareSetup,
        style: context.font.bodyMedium,
      ),
      if (result.mobileAccess != BullVaultMobileAccess.available &&
          result.record.recoveryPackage.policy.delayedMobileRecoveryKey !=
              null) ...[
        const Gap(24),
        Text(
          context.loc.bullVaultRestoreMobilePassphraseLabel,
          style: context.font.bodyMedium,
        ),
        const Gap(8),
        ExcludeSemantics(
          child: BullInputText(
            value: _mobilePassphrase,
            onChanged: (value) => setState(() => _mobilePassphrase = value),
            disabled: isRestoring,
            obscure: true,
            enableSuggestions: false,
            autocorrect: false,
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            maxLines: 1,
          ),
        ),
        const Gap(8),
        Text(
          context.loc.bullVaultRestoreMobilePassphraseDescription,
          style: context.font.bodySmall,
        ),
        const Gap(16),
        BullButton.big(
          label: context.loc.bullVaultRestoreMobilePassphraseAction,
          onPressed: _restoreMobile,
          disabled:
              isRestoring ||
              _mobilePassphrase.isEmpty ||
              _restoredSource == null,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
      if (isRestoring) ...[const Gap(16), const LinearProgressIndicator()],
      const Gap(32),
      BullButton.big(
        label: context.loc.continueButton,
        disabled: isRestoring,
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
        onPressed: () => context.pushReplacementNamed(
          BullVaultFacade.settingsRouteName,
          pathParameters: {'walletId': result.wallet.id},
          extra: result.wallet.label ?? context.loc.bullVaultWalletLabel,
        ),
      ),
    ],
  );

  Future<void> _pickPackage() async {
    final picked = await context
        .read<BullVaultRestoreCubit>()
        .pickRecoveryFile();
    if (!mounted) return;
    switch (picked) {
      case Err(:final failure):
        SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
      case Ok(value: final source?):
        await _restoreSource(
          kind: BullVaultRestoreInputKind.recoveryPackage,
          source: source,
        );
      case Ok():
        break;
    }
  }

  Future<void> _restoreSource({
    required BullVaultRestoreInputKind kind,
    required String source,
  }) async {
    final cubit = context.read<BullVaultRestoreCubit>();
    if (cubit.state.isRestoring) return;
    _restoredSource = (kind: kind, source: source);
    await cubit.restore(kind: kind, source: source, label: _label);
  }

  Future<void> _restoreDescriptor() => _restoreSource(
    kind: BullVaultRestoreInputKind.descriptor,
    source: _descriptor,
  );

  Future<void> _restoreMobile() async {
    final input = _restoredSource;
    if (input == null || _mobilePassphrase.isEmpty) return;
    try {
      await context.read<BullVaultRestoreCubit>().restore(
        kind: input.kind,
        source: input.source,
        label: _label,
        mobilePassphrase: _mobilePassphrase,
      );
    } finally {
      if (mounted) setState(() => _mobilePassphrase = '');
    }
  }

  Future<void> _scanDescriptor() async {
    final descriptor = await context.pushNamed<String>(
      BullVaultRouter.scannerRouteName,
      extra: BullVaultScannerPurpose.descriptor,
    );
    if (!mounted || descriptor == null || descriptor.trim().isEmpty) return;
    setState(() => _descriptor = descriptor);
  }
}
