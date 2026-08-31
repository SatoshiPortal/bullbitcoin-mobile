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
import 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BullVaultRestoreScreen extends StatefulWidget {
  const BullVaultRestoreScreen({super.key});

  @override
  State<BullVaultRestoreScreen> createState() => _BullVaultRestoreScreenState();
}

class _BullVaultRestoreScreenState extends State<BullVaultRestoreScreen> {
  static const _maxPackageBytes = 1024 * 1024;

  final _labelController = TextEditingController();
  final _descriptorController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_labelController.text.isEmpty) {
      _labelController.text = context.loc.bullVaultWalletLabel;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptorController.dispose();
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
                context.pop(result);
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
                TextField(
                  controller: _labelController,
                  enabled: !state.isRestoring,
                  decoration: InputDecoration(
                    labelText: context.loc.labelInputLabel,
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
                TextField(
                  controller: _descriptorController,
                  enabled: !state.isRestoring,
                  minLines: 4,
                  maxLines: 8,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: context.loc.bullVaultDescriptorHint,
                  ),
                ),
                const Gap(16),
                BBButton.big(
                  label: context.loc.bullVaultScanQr,
                  onPressed: _scanDescriptor,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                  iconData: Icons.qr_code_scanner,
                  iconFirst: true,
                  outlined: true,
                  borderColor: context.appColors.secondary,
                  disabled: state.isRestoring,
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
        label: _labelController.text,
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
        source: _descriptorController.text,
        label: _labelController.text,
      );

  Future<void> _scanDescriptor() async {
    final descriptor = await context.pushNamed<String>(
      BullVaultRouter.scannerRouteName,
      extra: BullVaultScannerPurpose.descriptor,
    );
    if (!mounted || descriptor == null || descriptor.trim().isEmpty) return;
    _descriptorController.text = descriptor;
  }
}
