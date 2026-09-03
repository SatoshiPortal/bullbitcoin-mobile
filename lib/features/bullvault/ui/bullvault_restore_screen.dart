import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_state.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, BullPasteInput, Gap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_privacy/screen_privacy.dart';

class BullVaultRestoreScreen extends StatefulWidget {
  const BullVaultRestoreScreen({super.key});

  @override
  State<BullVaultRestoreScreen> createState() => _BullVaultRestoreScreenState();
}

class _BullVaultRestoreScreenState extends State<BullVaultRestoreScreen>
    with PrivacyScreen {
  static const _maxPackageBytes = 1024 * 1024;

  var _label = '';
  var _mobilePassphrase = '';
  var _descriptor = '';

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
          child: BlocConsumer<BullVaultRestoreCubit, BullVaultRestoreState>(
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
              if (state.result case final result?) {
                context.pushReplacementNamed(
                  BullVaultFacade.settingsRouteName,
                  pathParameters: {'walletId': result.wallet.id},
                  extra:
                      result.wallet.label ?? context.loc.bullVaultWalletLabel,
                );
              }
            },
            builder: (context, state) => ListView(
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
                const Gap(16),
                Text(
                  context.loc.bullVaultRestoreMobilePassphraseLabel,
                  style: context.font.bodyMedium,
                ),
                const Gap(8),
                BullInputText(
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
                const Gap(8),
                Text(
                  context.loc.bullVaultRestoreMobilePassphraseDescription,
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
                BBButton.big(
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
                BBButton.big(
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
        ),
      ),
    );
  }

  Future<void> _pickPackage() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
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
      final content = await file.readAsString();
      if (!mounted) return;
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
