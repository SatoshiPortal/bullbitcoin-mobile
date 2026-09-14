import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_state.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInputText, BullPasteInput, Gap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_policy_panel.dart';
import 'package:bb_mobile/locator.dart';

class BullVaultRestoreScreen extends StatefulWidget {
  /// Called with a chosen file that is a BIP138 artifact rather than a recovery
  /// package. Opening one needs a cosigner's public account key, which this
  /// screen does not ask for; the recovery landing routes it onwards.
  final void Function(Uint8List bytes)? onEncryptedDescriptorFile;

  const BullVaultRestoreScreen({super.key, this.onEncryptedDescriptorFile});

  @override
  State<BullVaultRestoreScreen> createState() => _BullVaultRestoreScreenState();
}

class _BullVaultRestoreScreenState extends State<BullVaultRestoreScreen>
    with PrivacyScreen {
  static const _maxPackageBytes = 1024 * 1024;

  /// Every BIP138 artifact starts with these six bytes.
  static final _bip138Magic = ascii.encode('BIP138');
  late final Future<void> _privacyFuture = enableScreenPrivacy();

  var _label = '';
  var _mobilePassphrase = '';
  var _descriptor = '';

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
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            onBack: () => context.pop(),
            backEnabled: !isRestoring,
            title: context.loc.bullVaultRestoreTitle,
          ),
        ),
        body: SafeArea(
          child: PrivacyGate(
            protection: _privacyFuture,
            unprotected: const PrivacyUnavailableNotice(standalone: false),
            builder: (context) =>
                BlocConsumer<BullVaultRestoreCubit, BullVaultRestoreState>(
                  listenWhen: (previous, current) =>
                      previous.failure != current.failure ||
                      previous.result != current.result,
                  listener: (context, state) {
                    if (state.failure case final failure?) {
                      SnackBarUtils.showSnackBar(
                        context,
                        failure.toTranslated(context),
                      );
                    }
                  },
                  builder: (context, state) => state.result != null
                      ? _restored(context, state.result!)
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
                              onChanged: (value) =>
                                  setState(() => _label = value),
                              disabled: state.isRestoring,
                              maxLines: 1,
                            ),
                            const Gap(16),
                            Text(
                              context.loc.bullVaultRestoreMobilePassphraseLabel,
                              style: context.font.bodyMedium,
                            ),
                            const Gap(8),
                            ExcludeSemantics(
                              child: BullInputText(
                                value: _mobilePassphrase,
                                onChanged: (value) =>
                                    setState(() => _mobilePassphrase = value),
                                disabled: state.isRestoring,
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
                              context
                                  .loc
                                  .bullVaultRestoreMobilePassphraseDescription,
                              style: context.font.bodySmall?.copyWith(
                                color: context.appColors.textMuted,
                              ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                              onChanged: (value) =>
                                  setState(() => _descriptor = value),
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
                              label:
                                  context.loc.bullVaultRestoreDescriptorAction,
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
          ),
        ),
      ),
    );
  }

  Widget _restored(
    BuildContext context,
    BullVaultRestoreResult result,
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
      const Gap(24),
      BlocProvider(
        create: (_) =>
            locator<BullVaultSettingsCubit>()..load(result.wallet.id),
        child: BlocBuilder<BullVaultSettingsCubit, BullVaultSettingsState>(
          builder: (context, state) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final inspection = state.inspection;
            if (inspection != null) {
              return BullVaultPolicyPanel(inspection: inspection);
            }
            // The descriptor is already restored. A failed private-key probe
            // must not hide its policy or turn restoration into a failure.
            return WalletPolicyView(wallet: result.wallet);
          },
        ),
      ),
      const Gap(32),
      BullButton.big(
        label: context.loc.continueButton,
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
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.onEncryptedDescriptorFile == null
            ? const ['json']
            : const ['json', 'bip138'],
      );
      if (!mounted || selection == null || selection.files.isEmpty) return;
      final path = selection.files.single.path;
      if (path == null) return;
      final file = File(path);
      if (await file.length() > _maxPackageBytes) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            context.loc.bullVaultFailureInvalidRecovery,
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final handOver = widget.onEncryptedDescriptorFile;
      if (handOver != null && _isEncryptedDescriptor(bytes)) {
        handOver(bytes);
        return;
      }
      final String content;
      try {
        content = utf8.decode(bytes);
      } on FormatException {
        SnackBarUtils.showSnackBar(
          context,
          context.loc.bullVaultFailureInvalidRecovery,
        );
        return;
      }
      await context.read<BullVaultRestoreCubit>().restore(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: content,
        label: _label,
        mobilePassphrase: _mobilePassphrase,
      );
    } on FileSystemException {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        context.loc.bullVaultFailureInvalidRecovery,
      );
    }
  }

  static bool _isEncryptedDescriptor(Uint8List bytes) {
    if (bytes.length <= _bip138Magic.length) return false;
    for (var i = 0; i < _bip138Magic.length; i++) {
      if (bytes[i] != _bip138Magic[i]) return false;
    }
    return true;
  }

  Future<void> _restoreDescriptor() =>
      context.read<BullVaultRestoreCubit>().restore(
        kind: BullVaultRestoreInputKind.descriptor,
        source: _descriptor,
        label: _label,
        mobilePassphrase: _mobilePassphrase,
      );

  Future<void> _scanDescriptor() async {
    final descriptor = await context.pushNamed<String>(
      BullVaultRouter.scannerRouteName,
      extra: BullVaultScannerPurpose.descriptor,
    );
    if (!mounted || descriptor == null || descriptor.trim().isEmpty) return;
    setState(() => _descriptor = descriptor);
  }
}
